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
        log(tr("Check complete"));
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
    log(tr("Checking server %1:%2").arg(hostName, port));

    const bool isIpLiteral = !QHostAddress(hostName).isNull();
    if (isIpLiteral) {
        log(tr("Server address is an IP, no DNS lookup needed"));
    } else {
        beginStep();
        QHostInfo::lookupHost(hostName, this, [this](const QHostInfo &info) {
            if (info.error() != QHostInfo::NoError) {
                log(tr("Could not find the server address: %1").arg(info.errorString()));
                m_failedStage = "dns";
            } else {
                QStringList addresses;
                const auto hostAddresses = info.addresses();
                for (const QHostAddress &address : hostAddresses) {
                    addresses.append(address.toString());
                }
                log(tr("Server address found: %1").arg(addresses.join(", ")));
            }
            endStep();
        });
    }

    if (transportProto.compare("tcp", Qt::CaseInsensitive) == 0) {
        checkTcpReachability(hostName, port.toUShort());
    } else {
        log(tr("Server works over UDP — the port is checked when you connect"));
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
        log(tr("Server responds (%1 ms)").arg(elapsed->elapsed()));
        socket->abort();
        socket->deleteLater();
        delete elapsed;
        endStep();
    });

    connect(socket, &QTcpSocket::errorOccurred, this, [this, socket, elapsed](QAbstractSocket::SocketError) {
        log(tr("Server is not responding: %1").arg(socket->errorString()));
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
            log(tr("Could not determine your external IP: %1").arg(reply->errorString()));
        } else {
            const QString externalIp = QString::fromUtf8(reply->readAll()).trimmed();
            log(tr("Your external IP: %1").arg(externalIp));
            if (externalIp == serverHostName) {
                log(tr("Your traffic goes through this server"));
            } else if (isVpnActive) {
                log(tr("VPN is on, but traffic exits through a different server (another profile or route)"));
            } else {
                log(tr("VPN is off — this is your normal IP from the provider"));
            }
        }
        reply->deleteLater();
        endStep();
    });
}
