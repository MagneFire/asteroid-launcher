/*
 * SPDX-FileCopyrightText: 2026 Darrel Griët <dgriet@gmail.com>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#ifndef AODFACEBUILDER_H
#define AODFACEBUILDER_H

#include <QDate>
#include <QObject>
#include <QPointer>
#include <QRectF>
#include <QSharedPointer>
#include <QTimer>
#include <QVariantMap>

class QQuickItem;
class QQuickItemGrabResult;

/*!
 * \brief Describes the current watchface to the second display daemon.
 *
 * Watches with a co-processor that draws the always-on display need the
 * face as a background image plus a digit strip and the positions of the
 * hour and minute digits. The builder finds the hour and minute Text items
 * of the loaded watchface, renders their font into a strip, grabs the rest
 * of the face as the background and hands the result to the daemon.
 */
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
    struct TimeLabel
    {
        QPointer<QQuickItem> item;
        bool wasVisible = true;
    };
    enum class LabelSearch { Found, None, Ambiguous };

    void queryCapabilities();
    void setSupported(bool supported);
    LabelSearch findTimeLabels(QQuickItem *watchface, TimeLabel *hours, TimeLabel *minutes) const;
    void onGrabReady();
    void onGrabTimeout();
    QRectF labelRect(QQuickItem *label) const;
    void clearFace();
    void finish(bool ok);

    bool m_supported = false;
    bool m_busy = false;
    int m_generation = 0;
    QString m_directory;
    QString m_acceptedDirectory;
    QPointer<QQuickItem> m_watchface;
    TimeLabel m_hours;
    TimeLabel m_minutes;
    QSharedPointer<QQuickItemGrabResult> m_grab;
    QTimer m_grabTimeout;
    QDate m_grabbedDate;
    int m_grabbedHour = -1;
};

#endif
