#include "diagnosticsController.h"

#include <QElapsedTimer>
#include <QHostAddress>
#include <QHostInfo>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTcpSocket>
#include <QTime>
#include <QTimer>

DiagnosticsController::DiagnosticsController(QObject *parent)
    : QObject(parent), m_networkManager(new QNetworkAccessManager(this))
{
}

bool DiagnosticsController::isCheckInProgress() const
{
    return m_pendingSteps > 0;
}

void DiagnosticsController::log(const QString &line)
{
    emit logAppended(QTime::currentTime().toString("HH:mm:ss") + "  " + line);
}

void DiagnosticsController::beginStep()
{
    ++m_pendingSteps;
    emit checkStateChanged();
}

void DiagnosticsController::endStep()
{
    --m_pendingSteps;
    if (m_pendingSteps <= 0) {
        m_pendingSteps = 0;
        log(tr("Check finished"));
        log("");
        emit checkCompleted(m_failedStage.isEmpty(), m_failedStage);
    }
    emit checkStateChanged();
}

void DiagnosticsController::startCheck(const QString &hostName, const QString &port, const QString &transportProto,
                                       bool isVpnActive)
{
    if (isCheckInProgress()) {
        return;
    }

    m_failedStage.clear();
    log(tr("Checking endpoint %1:%2").arg(hostName, port));

    const bool isIpLiteral = !QHostAddress(hostName).isNull();
    if (isIpLiteral) {
        log(tr("Endpoint is an IP address, no DNS resolution required"));
    } else {
        beginStep();
        QHostInfo::lookupHost(hostName, this, [this](const QHostInfo &info) {
            if (info.error() != QHostInfo::NoError) {
                log(tr("DNS resolution failed: %1").arg(info.errorString()));
                m_failedStage = "dns";
            } else {
                QStringList addresses;
                const auto hostAddresses = info.addresses();
                for (const QHostAddress &address : hostAddresses) {
                    addresses.append(address.toString());
                }
                log(tr("DNS resolved: %1").arg(addresses.join(", ")));
            }
            endStep();
        });
    }

    if (transportProto.compare("tcp", Qt::CaseInsensitive) == 0) {
        checkTcpReachability(hostName, port.toUShort());
    } else {
        log(tr("Transport protocol is UDP — port reachability probe is not applicable"));
    }

    fetchExternalIp(hostName, isVpnActive);
}

void DiagnosticsController::checkTcpReachability(const QString &hostName, quint16 port)
{
    beginStep();

    auto *socket = new QTcpSocket(this);
    auto *timeoutTimer = new QTimer(socket);
    auto *elapsed = new QElapsedTimer();
    elapsed->start();

    timeoutTimer->setSingleShot(true);

    connect(socket, &QTcpSocket::connected, this, [this, socket, elapsed]() {
        log(tr("TCP port is reachable, connect took %1 ms").arg(elapsed->elapsed()));
        socket->abort();
        socket->deleteLater();
        delete elapsed;
        endStep();
    });

    connect(socket, &QTcpSocket::errorOccurred, this, [this, socket, elapsed](QAbstractSocket::SocketError) {
        log(tr("TCP connection failed: %1").arg(socket->errorString()));
        m_failedStage = "connect";
        socket->deleteLater();
        delete elapsed;
        endStep();
    });

    connect(timeoutTimer, &QTimer::timeout, this, [socket]() {
        socket->abort(); // triggers errorOccurred with timeout-ish error
    });

    timeoutTimer->start(5000);
    socket->connectToHost(hostName, port);
}

void DiagnosticsController::fetchExternalIp(const QString &serverHostName, bool isVpnActive)
{
    beginStep();

    QNetworkRequest request(QUrl("https://api.ipify.org?format=text"));
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(10000);

    QNetworkReply *reply = m_networkManager->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply, serverHostName, isVpnActive]() {
        if (reply->error() != QNetworkReply::NoError) {
            log(tr("Failed to get external IP: %1").arg(reply->errorString()));
        } else {
            const QString externalIp = QString::fromUtf8(reply->readAll()).trimmed();
            log(tr("External IP: %1").arg(externalIp));
            if (externalIp == serverHostName) {
                log(tr("External IP matches this server — traffic goes through it"));
            } else if (isVpnActive) {
                log(tr("VPN is active, but traffic exits through a different endpoint (another profile or a via-route)"));
            } else {
                log(tr("VPN is not connected — this is your direct provider IP"));
            }
        }
        reply->deleteLater();
        endStep();
    });
}
