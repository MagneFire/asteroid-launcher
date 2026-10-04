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
#include <QFont>
#include <QFontMetricsF>
#include <QImage>
#include <QPainter>
#include <QQuickItem>
#include <QQuickItemGrabResult>
#include <QStandardPaths>
#include <QtMath>
#include <limits>

namespace {

const char SecondDisplayService[] = "org.asteroid.SecondDisplay";
const char SecondDisplayPath[] = "/Display";
const char SecondDisplayInterface[] = "org.asteroid.SecondDisplay.Display";
const char CapabilitiesProperty[] = "Capabilities";
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

QImage renderDigits(QQuickItem *label, const QImage &background, const QRectF &rect, bool color)
{
    QFont font = label->property("font").value<QFont>();
    const QFontMetricsF metrics(font);
    qreal cellWidth = 0;
    for (int digit = 0; digit < Glyphs; ++digit)
        cellWidth = qMax(cellWidth, metrics.horizontalAdvance(QString::number(digit)));
    const int glyphWidth = qCeil(cellWidth);
    const int glyphHeight = qCeil(label->height());
    if (glyphWidth <= 0 || glyphHeight <= 0)
        return QImage();

    const QPoint sample = rect.center().toPoint();
    const QRgb behind = background.valid(sample) ? background.pixel(sample) : qRgb(0, 0, 0);
    QImage digits(glyphWidth, glyphHeight * Glyphs, QImage::Format_ARGB32);
    digits.fill(Qt::transparent);
    QPainter painter(&digits);
    if (color)
        font.setStyleStrategy(QFont::NoAntialias);
    painter.setFont(font);
    painter.setPen(labelColor(label));
    for (int digit = 0; digit < Glyphs; ++digit)
        painter.drawText(QRectF(0, digit * glyphHeight, glyphWidth, glyphHeight), Qt::AlignCenter, QString::number(digit));
    painter.end();
    flattenEdges(&digits, behind);
    if (color)
        quantizeToPalette(&digits);
    return digits;
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

AodFaceBuilder::LabelSearch AodFaceBuilder::findTimeLabels(QQuickItem *watchface, TimeLabel *hours,
                                                            TimeLabel *minutes) const
{
    const QDateTime now = QDateTime::currentDateTime();
    QList<QQuickItem *> texts;
    collectTextItems(watchface, &texts);
    const QList<QQuickItem *> hourItems = itemsWithText(texts, hourTexts(now));
    const QList<QQuickItem *> minuteItems = itemsWithText(texts, minuteTexts(now));
    if (hourItems.isEmpty() || minuteItems.isEmpty()) {
        qInfo() << "AOD face: found" << hourItems.size() << "hour and" << minuteItems.size() << "minute labels";
        return LabelSearch::None;
    }
    if (hourItems.size() != 1 || minuteItems.size() != 1 || hourItems.first() == minuteItems.first()) {
        qInfo() << "AOD face: ambiguous labels," << hourItems.size() << "hour and" << minuteItems.size() << "minute";
        return LabelSearch::Ambiguous;
    }
    hours->item = hourItems.first();
    minutes->item = minuteItems.first();
    return LabelSearch::Found;
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
    const LabelSearch search = findTimeLabels(watchface, &m_hours, &m_minutes);
    if (search != LabelSearch::Found) {
        if (search == LabelSearch::None && clearOnFailure)
            clearFace();
        finish(false);
        return true;
    }
    m_watchface = watchface;
    for (TimeLabel *label : {&m_hours, &m_minutes}) {
        label->wasVisible = label->item->isVisible();
        label->item->setVisible(false);
    }
    m_grab = watchface->grabToImage();
    if (!m_grab) {
        for (TimeLabel *label : {&m_hours, &m_minutes})
            label->item->setVisible(label->wasVisible);
        finish(false);
        return true;
    }
    connect(m_grab.data(), &QQuickItemGrabResult::ready, this, &AodFaceBuilder::onGrabReady);
    m_grabTimeout.start();
    return true;
}

void AodFaceBuilder::onGrabTimeout()
{
    if (!m_grab)
        return;
    qWarning() << "AOD face: the watchface grab did not complete";
    disconnect(m_grab.data(), nullptr, this, nullptr);
    m_grab.reset();
    for (TimeLabel *label : {&m_hours, &m_minutes}) {
        if (label->item)
            label->item->setVisible(label->wasVisible);
    }
    finish(false);
}

QRectF AodFaceBuilder::labelRect(QQuickItem *label) const
{
    return m_watchface->mapRectFromItem(label, QRectF(0, 0, label->width(), label->height()));
}

void AodFaceBuilder::onGrabReady()
{
    m_grabTimeout.stop();
    QImage background = m_grab->image().convertToFormat(QImage::Format_ARGB32);
    m_grab.reset();
    for (TimeLabel *label : {&m_hours, &m_minutes}) {
        if (label->item)
            label->item->setVisible(label->wasVisible);
    }
    if (!m_watchface || !m_hours.item || !m_minutes.item)
        return finish(false);

    QImage opaque(background.size(), QImage::Format_ARGB32);
    opaque.fill(Qt::black);
    {
        QPainter painter(&opaque);
        painter.drawImage(0, 0, background);
    }
    background = opaque;

    const QRectF hourRect = labelRect(m_hours.item);
    const QRectF minuteRect = labelRect(m_minutes.item);
    const bool color = !isGrey(labelColor(m_hours.item).rgb()) || !isGrey(labelColor(m_minutes.item).rgb())
        || !isGreyImage(background);
    const QImage hourDigits = renderDigits(m_hours.item, background, hourRect, color);
    const QImage minuteDigits = renderDigits(m_minutes.item, background, minuteRect, color);
    if (hourDigits.isNull() || minuteDigits.isNull())
        return finish(false);
    if (color)
        quantizeToPalette(&background);

    const QString directory = faceDirectory() + "/" + QString::number(++m_generation);
    QDir().mkpath(directory);
    m_directory = directory;
    const QString backgroundPath = directory + "/background.png";
    const QString digitsPath = directory + "/digits.png";
    const QString minuteDigitsPath = directory + "/minute-digits.png";
    if (!background.save(backgroundPath) || !hourDigits.save(digitsPath) || !minuteDigits.save(minuteDigitsPath))
        return finish(false);

    QVariantMap description;
    description["background"] = backgroundPath;
    description["digits"] = digitsPath;
    description["minuteDigits"] = minuteDigitsPath;
    description["color"] = color;
    description["hoursX"] = qRound(hourRect.center().x() - hourDigits.width());
    description["hoursY"] = qRound(hourRect.top());
    description["minutesX"] = qRound(minuteRect.center().x() - minuteDigits.width());
    description["minutesY"] = qRound(minuteRect.top());

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
    m_hours = TimeLabel();
    m_minutes = TimeLabel();
    m_busy = false;
    emit finished(ok);
}
