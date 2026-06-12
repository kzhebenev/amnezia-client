#ifndef IMPORTCONTROLLER_H
#define IMPORTCONTROLLER_H

#include <QObject>
#include <QJsonArray>
#include <QJsonObject>
#include <QByteArray>
#include <QMap>
#include <QUrl>
#include <QVariantMap>

class QNetworkAccessManager;

#include "core/repositories/secureServersRepository.h"
#include "core/repositories/secureAppSettingsRepository.h"
#include "core/utils/errorCodes.h"
#include "core/utils/routeModes.h"
#include "core/utils/commonStructs.h"

namespace
{
    enum class ConfigTypes {
        Amnezia,
        OpenVpn,
        WireGuard,
        Awg,
        Xray,
        ShadowSocks,
        Backup,
        Invalid
    };
}

using namespace amnezia;

class ImportController : public QObject
{
    Q_OBJECT

public:
    struct ImportResult
    {
        ErrorCode errorCode = ErrorCode::NoError;
        QJsonObject config;
        QString configFileName;
        QString maliciousWarningText;
        ConfigTypes configType = ConfigTypes::Invalid;
        bool isNativeWireGuardConfig = false;
    };

    explicit ImportController(SecureServersRepository* serversRepository,
                              SecureAppSettingsRepository* appSettingsRepository,
                              QObject *parent = nullptr);

    struct QrParseResult {
        bool success = false;
        ImportResult importResult;
        int chunksReceived = 0;
        int chunksTotal = 0;
    };

    ImportResult extractConfigFromData(const QString &data, const QString &configFileName = "");
    ImportResult extractConfigFromQr(const QByteArray &data);

    static bool isSubscriptionLink(const QString &data);
    ErrorCode importSubscription(const QString &data);
    ErrorCode refreshSubscriptions(int &updatedCount);
    bool hasSubscriptions() const;
    void requestSubscriptionStatuses();

    void startDecodingQr();
    QrParseResult parseQrCodeChunk(const QString &code);
    bool isQrDecodingActive() const;
    int qrChunksReceived() const;
    int qrChunksTotal() const;

    void importConfig(const QJsonObject &config);
    QJsonObject processNativeWireGuardConfig(const QJsonObject &config);

signals:
    void importFinished();
    void importErrorOccurred(ErrorCode errorCode, bool goToPageHome);
    void restoreAppConfig(const QByteArray &data);
    void subscriptionStatusesUpdated(const QVariantMap &statuses);

private:
    struct SubscriptionEndpoint
    {
        QString baseUrl;
        QString token;

        bool isValid() const { return !baseUrl.isEmpty() && !token.isEmpty(); }
        QString cacheKey() const { return baseUrl + "|" + token; }
    };

    static SubscriptionEndpoint parseSubscriptionInput(const QString &data);
    SubscriptionEndpoint subscriptionEndpointForServer(const QString &serverId) const;
    QList<SubscriptionEndpoint> storedSubscriptionEndpoints() const;
    QString serverIdForSubscriptionProfile(const SubscriptionEndpoint &endpoint, const QString &profileId,
                                           const QString &profileName) const;
    ErrorCode fetchSubscriptionProfiles(const SubscriptionEndpoint &endpoint, QJsonArray &profiles) const;
    QJsonObject buildServerConfigFromSubscriptionProfile(const QJsonObject &profile,
                                                         const SubscriptionEndpoint &endpoint) const;
    ErrorCode refreshSubscriptionFromProfiles(const SubscriptionEndpoint &endpoint, const QJsonArray &profiles,
                                              int &updatedCount);

    ConfigTypes checkConfigFormat(const QString &config) const;
    QJsonObject extractOpenVpnConfig(const QString &data) const;
    QJsonObject extractWireGuardConfig(const QString &data, ConfigTypes &configType) const;
    QJsonObject extractXrayConfig(const QString &data, ConfigTypes configType, const QString &description = "") const;
    void checkForMaliciousStrings(const QJsonObject &serverConfig, QString &warningText) const;
    void processAmneziaConfig(QJsonObject &config) const;

    SecureServersRepository* m_serversRepository;
    SecureAppSettingsRepository* m_appSettingsRepository;

    QNetworkAccessManager* m_statusNetworkManager = nullptr;

    QMap<int, QByteArray> m_qrCodeChunks;
    bool m_isQrCodeProcessed = false;
    int m_totalQrCodeChunksCount = 0;
    int m_receivedQrCodeChunksCount = 0;
};

#endif // IMPORTCONTROLLER_H
