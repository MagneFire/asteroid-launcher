/*
 * SPDX-FileCopyrightText: 2026 Darrel Griët <dgriet@gmail.com>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#ifndef AODFACEBUILDER_H
#define AODFACEBUILDER_H

#include <QColor>
#include <QDate>
#include <QImage>
#include <QObject>
#include <QPointer>
#include <QRectF>
#include <QSharedPointer>
#include <QStringList>
#include <QTimer>
#include <QVariantMap>

class QQuickItem;
class QQuickItemGrabResult;

class AodFaceBuilder : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool supported READ supported NOTIFY supportedChanged)

public:
    explicit AodFaceBuilder(QObject *parent = nullptr);

    bool supported() const { return m_supported; }

    Q_INVOKABLE bool publish(QQuickItem *watchface, bool clearOnFailure);
    Q_INVOKABLE bool stale() const;

signals:
    void supportedChanged();
    void finished(bool ok);

private slots:
    void onServiceRegistered();
    void onServiceUnregistered();
    void onPropertiesChanged(const QString &interface, const QVariantMap &changed, const QStringList &invalidated);

private:
    struct Number
    {
        QList<QPointer<QQuickItem>> items;
        QList<bool> wasVisible;
        QPointer<QQuickItem> label;
        QStringList images;
        QColor color;
        bool invert = false;
    };
    struct Strip
    {
        QImage image;
        QPoint position;
    };
    enum class Search { Found, None, Ambiguous, Invalid };

    void queryCapabilities();
    void setSupported(bool supported);
    Search readDeclaration(QQuickItem *watchface, Number *hours, Number *minutes) const;
    bool readNumber(QQuickItem *watchface, const QVariant &value, Number *number) const;
    Search findTimeLabels(QQuickItem *watchface, Number *hours, Number *minutes) const;
    void hideNumbers();
    void restoreNumbers();
    void onGrabReady();
    void onGrabTimeout();
    QRectF itemRect(QQuickItem *item) const;
    bool isGreyNumber(const Number &number) const;
    Strip renderStrip(const Number &number, const QImage &background, bool color) const;
    void clearFace();
    void finish(bool ok);

    bool m_supported = false;
    bool m_busy = false;
    int m_generation = 0;
    QString m_directory;
    QString m_acceptedDirectory;
    QPointer<QQuickItem> m_watchface;
    Number m_hours;
    Number m_minutes;
    QSharedPointer<QQuickItemGrabResult> m_grab;
    QTimer m_grabTimeout;
    QDate m_grabbedDate;
    int m_grabbedHour = -1;
};

#endif
