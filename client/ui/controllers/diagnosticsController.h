#ifndef DIAGNOSTICSCONTROLLER_H
#define DIAGNOSTICSCONTROLLER_H

#include <QObject>

class QNetworkAccessManager;

class DiagnosticsController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool isCheckInProgress READ isCheckInProgress NOTIFY checkStateChanged)

public:
    explicit DiagnosticsController(QObject *parent = nullptr);

public slots:
    void startCheck(const QString &hostName, const QString &port, const QString &transportProto, bool isVpnActive);
    bool isCheckInProgress() const;

signals:
    void logAppended(const QString &line);
    void checkStateChanged();

private:
    void log(const QString &line);
    void beginStep();
    void endStep();
    void checkTcpReachability(const QString &hostName, quint16 port);
    void fetchExternalIp(const QString &serverHostName, bool isVpnActive);

    QNetworkAccessManager *m_networkManager;
    int m_pendingSteps = 0;
};

#endif // DIAGNOSTICSCONTROLLER_H
