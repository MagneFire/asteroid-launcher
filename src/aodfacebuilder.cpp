/*
 * SPDX-FileCopyrightText: 2026 Darrel Griët <dgriet@gmail.com>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include "aodfacebuilder.h"

#include <QColor>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QDBusVariant>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFont>
#include <QFontMetricsF>
#include <QImage>
#include <QPainter>
#include <QQuickItem>
#include <QQuickItemGrabResult>
#include <QJSValue>
#include <QQmlContext>
#include <QUrl>
#include <QStandardPaths>
#include <QtMath>
#include <limits>

namespace {

const char SecondDisplayService[] = "org.asteroid.SecondDisplay";
const char SecondDisplayPath[] = "/Display";
const char SecondDisplayInterface[] = "org.asteroid.SecondDisplay.Display";
const char CapabilitiesProperty[] = "Capabilities";
const char DeclarationProperty[] = "ambientDecomposition";
constexpr uint AodOffloadCapability = 1u << 7;
constexpr int Glyphs = 10;
constexpr int GreyTolerance = 8;
constexpr int GrabTimeoutMs = 5000;

const QList<QColor> ColorPalette{
    QColor(0, 0, 0),       QColor(64, 64, 64),    QColor(128, 128, 128), QColor(192, 192, 192),
    QColor(255, 255, 255), QColor(255, 0, 0),     QColor(0, 255, 0),     QColor(0, 0, 255),
    QColor(255, 255, 0),   QColor(0, 255, 255),   QColor(255, 0, 255),   QColor(255, 128, 0),
    QColor(128, 0, 0),     QColor(0, 128, 0),     QColor(0, 0, 128),     QColor(128, 128, 0),
};

QString faceDirectory()
{
    return QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation) + "/asteroid-launcher/aod-face";
}

bool isGrey(QRgb rgb)
{
    const int r = qRed(rgb);
    const int g = qGreen(rgb);
    const int b = qBlue(rgb);
    return qAbs(r - g) <= GreyTolerance && qAbs(g - b) <= GreyTolerance && qAbs(r - b) <= GreyTolerance;
}

bool isGreyImage(const QImage &image)
{
    for (int y = 0; y < image.height(); ++y) {
        const QRgb *line = reinterpret_cast<const QRgb *>(image.constScanLine(y));
        for (int x = 0; x < image.width(); ++x) {
            if (!isGrey(line[x]))
                return false;
        }
    }
    return true;
}

QRgb nearestPaletteColor(QRgb rgb)
{
    int best = 0;
    int bestDistance = std::numeric_limits<int>::max();
    for (int i = 0; i < ColorPalette.size(); ++i) {
        const QColor &c = ColorPalette[i];
        const int dr = qRed(rgb) - c.red();
        const int dg = qGreen(rgb) - c.green();
        const int db = qBlue(rgb) - c.blue();
        const int distance = dr * dr + dg * dg + db * db;
        if (distance < bestDistance) {
            bestDistance = distance;
            best = i;
        }
    }
    return ColorPalette[best].rgb();
}

void quantizeToPalette(QImage *image)
{
    for (int y = 0; y < image->height(); ++y) {
        QRgb *line = reinterpret_cast<QRgb *>(image->scanLine(y));
        for (int x = 0; x < image->width(); ++x) {
            if (qAlpha(line[x]) != 0)
                line[x] = nearestPaletteColor(line[x]);
        }
    }
}

QStringList hourTexts(const QDateTime &now)
{
    const int hour24 = now.time().hour();
    const int hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    QStringList texts{QString::number(hour24), QString("%1").arg(hour24, 2, 10, QChar('0')), QString::number(hour12),
                      QString("%1").arg(hour12, 2, 10, QChar('0'))};
    texts.removeDuplicates();
    return texts;
}

QStringList minuteTexts(const QDateTime &now)
{
    return {QString("%1").arg(now.time().minute(), 2, 10, QChar('0'))};
}

void collectTextItems(QQuickItem *item, QList<QQuickItem *> *texts)
{
    const auto children = item->childItems();
    for (QQuickItem *child : children) {
        if (!child->isVisible())
            continue;
        if (child->inherits("QQuickText"))
            texts->append(child);
        collectTextItems(child, texts);
    }
}

void flattenEdges(QImage *image, QRgb behind)
{
    for (int y = 0; y < image->height(); ++y) {
        QRgb *line = reinterpret_cast<QRgb *>(image->scanLine(y));
        for (int x = 0; x < image->width(); ++x) {
            const int alpha = qAlpha(line[x]);
            if (alpha == 0)
                continue;
            const int r = (qRed(line[x]) * alpha + qRed(behind) * (255 - alpha)) / 255;
            const int g = (qGreen(line[x]) * alpha + qGreen(behind) * (255 - alpha)) / 255;
            const int b = (qBlue(line[x]) * alpha + qBlue(behind) * (255 - alpha)) / 255;
            line[x] = qRgb(r, g, b);
        }
    }
}

QColor labelColor(QQuickItem *item)
{
    return item->property("color").value<QColor>();
}

QList<QQuickItem *> itemsWithText(const QList<QQuickItem *> &texts, const QStringList &wanted)
{
    QList<QQuickItem *> matches;
    for (QQuickItem *item : texts) {
        if (wanted.contains(item->property("text").toString().trimmed()))
            matches.append(item);
    }
    return matches;
}

}

AodFaceBuilder::AodFaceBuilder(QObject *parent)
    : QObject(parent)
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    auto *watcher = new QDBusServiceWatcher(SecondDisplayService, bus,
                                            QDBusServiceWatcher::WatchForRegistration
                                                | QDBusServiceWatcher::WatchForUnregistration,
                                            this);
    connect(watcher, &QDBusServiceWatcher::serviceRegistered, this, &AodFaceBuilder::onServiceRegistered);
    connect(watcher, &QDBusServiceWatcher::serviceUnregistered, this, &AodFaceBuilder::onServiceUnregistered);
    bus.connect(SecondDisplayService, SecondDisplayPath, "org.freedesktop.DBus.Properties", "PropertiesChanged", this,
                SLOT(onPropertiesChanged(QString, QVariantMap, QStringList)));
    m_grabTimeout.setSingleShot(true);
    m_grabTimeout.setInterval(GrabTimeoutMs);
    connect(&m_grabTimeout, &QTimer::timeout, this, &AodFaceBuilder::onGrabTimeout);
    queryCapabilities();
}

void AodFaceBuilder::queryCapabilities()
{
    QDBusMessage get = QDBusMessage::createMethodCall(SecondDisplayService, SecondDisplayPath,
                                                      "org.freedesktop.DBus.Properties", "Get");
    get << QString::fromLatin1(SecondDisplayInterface) << QString::fromLatin1(CapabilitiesProperty);
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(get), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *watcher) {
        QDBusPendingReply<QDBusVariant> reply = *watcher;
        watcher->deleteLater();
        setSupported(reply.isValid() && (reply.value().variant().toUInt() & AodOffloadCapability));
    });
}

void AodFaceBuilder::setSupported(bool supported)
{
    if (m_supported == supported)
        return;
    m_supported = supported;
    emit supportedChanged();
}

void AodFaceBuilder::onServiceRegistered()
{
    queryCapabilities();
}

void AodFaceBuilder::onServiceUnregistered()
{
    setSupported(false);
}

void AodFaceBuilder::onPropertiesChanged(const QString &interface, const QVariantMap &changed, const QStringList &)
{
    if (interface == QLatin1String(SecondDisplayInterface) && changed.contains(CapabilitiesProperty))
        setSupported(changed.value(CapabilitiesProperty).toUInt() & AodOffloadCapability);
}

bool AodFaceBuilder::stale() const
{
    const QDateTime now = QDateTime::currentDateTime();
    return m_grabbedDate != now.date() || (m_grabbedHour < 12) != (now.time().hour() < 12);
}

AodFaceBuilder::Search AodFaceBuilder::findTimeLabels(QQuickItem *watchface, Number *hours, Number *minutes) const
{
    const QDateTime now = QDateTime::currentDateTime();
    QList<QQuickItem *> texts;
    collectTextItems(watchface, &texts);
    const QList<QQuickItem *> hourItems = itemsWithText(texts, hourTexts(now));
    const QList<QQuickItem *> minuteItems = itemsWithText(texts, minuteTexts(now));
    if (hourItems.isEmpty() || minuteItems.isEmpty()) {
        qInfo() << "AOD face: found" << hourItems.size() << "hour and" << minuteItems.size() << "minute labels";
        return Search::None;
    }
    if (hourItems.size() != 1 || minuteItems.size() != 1 || hourItems.first() == minuteItems.first()) {
        qInfo() << "AOD face: ambiguous labels," << hourItems.size() << "hour and" << minuteItems.size() << "minute";
        return Search::Ambiguous;
    }
    hours->label = hourItems.first();
    hours->items = {hourItems.first()};
    minutes->label = minuteItems.first();
    minutes->items = {minuteItems.first()};
    return Search::Found;
}

bool AodFaceBuilder::readNumber(QQuickItem *watchface, const QVariant &value, Number *number) const
{
    if (auto *item = qobject_cast<QQuickItem *>(value.value<QObject *>())) {
        if (!item->inherits("QQuickText"))
            return false;
        number->label = item;
        number->items = {item};
        return true;
    }
    const QVariantMap map = value.toMap();
    const QVariantList cells = map.value("cells").toList();
    for (const QVariant &cell : cells) {
        auto *item = qobject_cast<QQuickItem *>(cell.value<QObject *>());
        if (!item)
            return false;
        number->items.append(item);
    }
    if (number->items.isEmpty() || number->items.size() > 2)
        return false;
    const QVariant images = map.value("images");
    QStringList sources;
    if (images.canConvert<QStringList>() && images.toStringList().size() == Glyphs) {
        sources = images.toStringList();
    } else {
        const QString pattern = images.toString();
        if (!pattern.contains("%1"))
            return false;
        for (int digit = 0; digit < Glyphs; ++digit)
            sources.append(pattern.arg(digit));
    }
    QQmlContext *context = qmlContext(watchface);
    for (const QString &source : sources) {
        const QUrl url = context ? context->resolvedUrl(QUrl(source)) : QUrl(source);
        const QString path = url.isLocalFile() ? url.toLocalFile() : (url.scheme() == "qrc" ? ":" + url.path() : url.toString());
        if (!QFile::exists(path))
            return false;
        number->images.append(path);
    }
    number->color = map.value("color", QColor(Qt::white)).value<QColor>();
    number->invert = map.value("invert").toBool();
    return true;
}

AodFaceBuilder::Search AodFaceBuilder::readDeclaration(QQuickItem *watchface, Number *hours, Number *minutes) const
{
    QVariant declaration = watchface->property(DeclarationProperty);
    if (!declaration.isValid())
        return Search::None;
    if (declaration.canConvert<QJSValue>())
        declaration = declaration.value<QJSValue>().toVariant();
    const QVariantMap map = declaration.toMap();
    if (map.isEmpty())
        return Search::None;
    if (!readNumber(watchface, map.value("hours"), hours) || !readNumber(watchface, map.value("minutes"), minutes)) {
        qWarning() << "AOD face: the watchface's" << DeclarationProperty << "is not usable";
        return Search::Invalid;
    }
    return Search::Found;
}

bool AodFaceBuilder::publish(QQuickItem *watchface, bool clearOnFailure)
{
    if (m_busy)
        return false;
    m_busy = true;
    if (!m_supported || !watchface) {
        finish(false);
        return true;
    }
    Search search = readDeclaration(watchface, &m_hours, &m_minutes);
    if (search == Search::None) {
        m_hours = Number();
        m_minutes = Number();
        search = findTimeLabels(watchface, &m_hours, &m_minutes);
    }
    if (search != Search::Found) {
        if (search != Search::Ambiguous && clearOnFailure)
            clearFace();
        finish(false);
        return true;
    }
    m_watchface = watchface;
    hideNumbers();
    m_grab = watchface->grabToImage();
    if (!m_grab) {
        restoreNumbers();
        finish(false);
        return true;
    }
    connect(m_grab.data(), &QQuickItemGrabResult::ready, this, &AodFaceBuilder::onGrabReady);
    m_grabTimeout.start();
    return true;
}

void AodFaceBuilder::hideNumbers()
{
    for (Number *number : {&m_hours, &m_minutes}) {
        number->wasVisible.clear();
        for (const QPointer<QQuickItem> &item : number->items) {
            number->wasVisible.append(item && item->isVisible());
            if (item)
                item->setVisible(false);
        }
    }
}

void AodFaceBuilder::restoreNumbers()
{
    for (Number *number : {&m_hours, &m_minutes}) {
        for (int i = 0; i < number->items.size() && i < number->wasVisible.size(); ++i) {
            if (number->items[i])
                number->items[i]->setVisible(number->wasVisible[i]);
        }
    }
}

void AodFaceBuilder::onGrabTimeout()
{
    if (!m_grab)
        return;
    qWarning() << "AOD face: the watchface grab did not complete";
    disconnect(m_grab.data(), nullptr, this, nullptr);
    m_grab.reset();
    restoreNumbers();
    finish(false);
}

QRectF AodFaceBuilder::itemRect(QQuickItem *item) const
{
    return m_watchface->mapRectFromItem(item, QRectF(0, 0, item->width(), item->height()));
}

bool AodFaceBuilder::isGreyNumber(const Number &number) const
{
    const QColor color = number.label ? labelColor(number.label) : number.color;
    return isGrey(color.rgb());
}

AodFaceBuilder::Strip AodFaceBuilder::renderStrip(const Number &number, const QImage &background, bool color) const
{
    Strip strip;
    for (const QPointer<QQuickItem> &item : number.items) {
        if (!item)
            return strip;
    }
    const QRectF first = itemRect(number.items.first());
    const QPoint sample = first.center().toPoint();
    const QRgb behind = background.valid(sample) ? background.pixel(sample) : qRgb(0, 0, 0);

    if (number.label) {
        QFont font = number.label->property("font").value<QFont>();
        const QFontMetricsF metrics(font);
        qreal cellWidth = 0;
        for (int digit = 0; digit < Glyphs; ++digit)
            cellWidth = qMax(cellWidth, metrics.horizontalAdvance(QString::number(digit)));
        const int glyphWidth = qCeil(cellWidth);
        const int glyphHeight = qCeil(first.height());
        if (glyphWidth <= 0 || glyphHeight <= 0)
            return strip;
        QImage digits(glyphWidth, glyphHeight * Glyphs, QImage::Format_ARGB32);
        digits.fill(Qt::transparent);
        QPainter painter(&digits);
        if (color)
            font.setStyleStrategy(QFont::NoAntialias);
        painter.setFont(font);
        painter.setPen(labelColor(number.label));
        for (int digit = 0; digit < Glyphs; ++digit)
            painter.drawText(QRectF(0, digit * glyphHeight, glyphWidth, glyphHeight), Qt::AlignCenter, QString::number(digit));
        painter.end();
        flattenEdges(&digits, behind);
        if (color)
            quantizeToPalette(&digits);
        strip.image = digits;
        strip.position = QPoint(qRound(first.center().x() - glyphWidth), qRound(first.top()));
        return strip;
    }

    const int glyphWidth = number.items.size() > 1 ? qRound(itemRect(number.items[1]).left() - first.left())
                                                   : qRound(first.width());
    const int glyphHeight = qRound(first.height());
    if (glyphWidth <= 0 || glyphHeight <= 0)
        return strip;
    QImage digits(glyphWidth, glyphHeight * Glyphs, QImage::Format_ARGB32);
    digits.fill(Qt::transparent);
    const QRgb tint = number.color.rgb();
    for (int digit = 0; digit < Glyphs; ++digit) {
        QImage glyph(number.images.value(digit));
        if (glyph.isNull())
            return Strip();
        glyph = glyph.convertToFormat(QImage::Format_ARGB32)
                    .scaled(qRound(first.width()), glyphHeight, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        const int left = (qRound(first.width()) - glyph.width()) / 2;
        const int top = digit * glyphHeight + (glyphHeight - glyph.height()) / 2;
        for (int y = 0; y < glyph.height(); ++y) {
            const QRgb *source = reinterpret_cast<const QRgb *>(glyph.constScanLine(y));
            QRgb *target = reinterpret_cast<QRgb *>(digits.scanLine(top + y));
            for (int x = 0; x < glyph.width(); ++x) {
                int coverage = qAlpha(source[x]);
                if (number.invert)
                    coverage = 255 - coverage;
                if (color && coverage < 128)
                    coverage = 0;
                else if (color)
                    coverage = 255;
                if (coverage > 0 && left + x >= 0 && left + x < glyphWidth)
                    target[left + x] = qRgba(qRed(tint), qGreen(tint), qBlue(tint), coverage);
            }
        }
    }
    flattenEdges(&digits, behind);
    if (color)
        quantizeToPalette(&digits);
    strip.image = digits;
    strip.position = QPoint(qRound(first.left()), qRound(first.top()));
    return strip;
}

void AodFaceBuilder::onGrabReady()
{
    m_grabTimeout.stop();
    QImage background = m_grab->image().convertToFormat(QImage::Format_ARGB32);
    m_grab.reset();
    restoreNumbers();
    if (!m_watchface)
        return finish(false);

    QImage opaque(background.size(), QImage::Format_ARGB32);
    opaque.fill(Qt::black);
    {
        QPainter painter(&opaque);
        painter.drawImage(0, 0, background);
    }
    background = opaque;

    const bool color = !isGreyNumber(m_hours) || !isGreyNumber(m_minutes) || !isGreyImage(background);
    const Strip hours = renderStrip(m_hours, background, color);
    const Strip minutes = renderStrip(m_minutes, background, color);
    if (hours.image.isNull() || minutes.image.isNull())
        return finish(false);
    if (color)
        quantizeToPalette(&background);

    const QString directory = faceDirectory() + "/" + QString::number(++m_generation);
    QDir().mkpath(directory);
    m_directory = directory;
    const QString backgroundPath = directory + "/background.png";
    const QString digitsPath = directory + "/digits.png";
    const QString minuteDigitsPath = directory + "/minute-digits.png";
    if (!background.save(backgroundPath) || !hours.image.save(digitsPath) || !minutes.image.save(minuteDigitsPath))
        return finish(false);

    QVariantMap description;
    description["background"] = backgroundPath;
    description["digits"] = digitsPath;
    description["minuteDigits"] = minuteDigitsPath;
    description["color"] = color;
    description["hoursX"] = hours.position.x();
    description["hoursY"] = hours.position.y();
    description["minutesX"] = minutes.position.x();
    description["minutesY"] = minutes.position.y();

    QDBusMessage set = QDBusMessage::createMethodCall(SecondDisplayService, SecondDisplayPath, SecondDisplayInterface, "SetFace");
    set << description;
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(set), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *watcher) {
        QDBusPendingReply<bool> reply = *watcher;
        watcher->deleteLater();
        const bool ok = reply.isValid() && reply.value();
        if (ok) {
            const QDateTime now = QDateTime::currentDateTime();
            m_grabbedDate = now.date();
            m_grabbedHour = now.time().hour();
            if (!m_acceptedDirectory.isEmpty())
                QDir(m_acceptedDirectory).removeRecursively();
            m_acceptedDirectory = m_directory;
            m_directory.clear();
        } else {
            qWarning() << "AOD face: SetFace failed" << reply.error().message();
        }
        finish(ok);
    });
}

void AodFaceBuilder::clearFace()
{
    QDBusMessage clear = QDBusMessage::createMethodCall(SecondDisplayService, SecondDisplayPath, SecondDisplayInterface, "ClearFace");
    QDBusConnection::sessionBus().asyncCall(clear);
}

void AodFaceBuilder::finish(bool ok)
{
    if (!m_directory.isEmpty()) {
        QDir(m_directory).removeRecursively();
        m_directory.clear();
    }
    m_watchface.clear();
    m_hours = Number();
    m_minutes = Number();
    m_busy = false;
    emit finished(ok);
}
