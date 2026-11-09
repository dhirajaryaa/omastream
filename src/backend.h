#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QVariantList>

// The app's engine: drives the omastream-cli as its process layer, mirrors
// runtime state from ~/.local/state/omastream/state.json, and persists
// settings through `omastream-cli config set` so the CLI stays the single
// owner of both files (bubble and bar watch the same state).
class Backend : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool streaming READ streaming NOTIFY stateChanged)
    Q_PROPERTY(QString elapsed READ elapsed NOTIFY stateChanged)
    Q_PROPERTY(QString statusLine READ statusLine NOTIFY stateChanged)
    Q_PROPERTY(QString mode READ mode NOTIFY stateChanged)
    Q_PROPERTY(bool camVisible READ camVisible NOTIFY stateChanged)
    Q_PROPERTY(QString camShape READ camShape NOTIFY stateChanged)
    Q_PROPERTY(bool camFlip READ camFlip NOTIFY stateChanged)
    Q_PROPERTY(bool privacyActive READ privacyActive NOTIFY stateChanged)
    Q_PROPERTY(QString privacyMode READ privacyMode NOTIFY stateChanged)
    Q_PROPERTY(bool starting READ starting NOTIFY busyChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(bool hasStreamKey READ hasStreamKey NOTIFY configChanged)
    Q_PROPERTY(bool hasAnyPlatformConfigured READ hasAnyPlatformConfigured NOTIFY configChanged)
    Q_PROPERTY(QString activePlatforms READ activePlatforms NOTIFY stateChanged)
    Q_PROPERTY(bool youtubeEnabled READ youtubeEnabled NOTIFY configChanged)
    Q_PROPERTY(QString youtubeKey READ youtubeKey NOTIFY configChanged)
    Q_PROPERTY(bool twitchEnabled READ twitchEnabled NOTIFY configChanged)
    Q_PROPERTY(QString twitchKey READ twitchKey NOTIFY configChanged)
    Q_PROPERTY(bool kickEnabled READ kickEnabled NOTIFY configChanged)
    Q_PROPERTY(QString kickKey READ kickKey NOTIFY configChanged)
    Q_PROPERTY(QString kickUrl READ kickUrl NOTIFY configChanged)
    Q_PROPERTY(QString streamKey READ streamKey NOTIFY configChanged)
    Q_PROPERTY(QString streamResolution READ streamResolution NOTIFY configChanged)
    Q_PROPERTY(QString audioSystem READ audioSystem NOTIFY configChanged)
    Q_PROPERTY(QString audioMic READ audioMic NOTIFY configChanged)
    Q_PROPERTY(bool micEnabled READ micEnabled NOTIFY configChanged)
    Q_PROPERTY(QString videoCodec READ videoCodec NOTIFY configChanged)
    Q_PROPERTY(int bitrate READ bitrate NOTIFY configChanged)
    Q_PROPERTY(QString screenSharpness READ screenSharpness NOTIFY configChanged)
    Q_PROPERTY(bool camOnStart READ camOnStart NOTIFY configChanged)
    Q_PROPERTY(bool cpuFallback READ cpuFallback NOTIFY configChanged)
    Q_PROPERTY(QVariantList systemOutputs READ systemOutputs NOTIFY audioDevicesChanged)
    Q_PROPERTY(QVariantList microphones READ microphones NOTIFY audioDevicesChanged)

public:
    explicit Backend(const QString &statePath = {}, const QString &configPath = {},
                     const QString &cli = {}, QObject *parent = nullptr);
    ~Backend();

    bool streaming() const { return m_streaming; }
    QString elapsed() const { return m_elapsed; }
    QString statusLine() const;
    QString mode() const { return m_mode; }
    bool camVisible() const { return m_camVisible; }
    QString camShape() const { return m_camShape; }
    bool camFlip() const { return m_camFlip; }
    bool privacyActive() const { return m_privacyActive; }
    QString privacyMode() const { return m_privacyMode; }
    bool starting() const { return m_starting; }
    bool hasStreamKey() const { return hasAnyPlatformConfigured(); }
    bool hasAnyPlatformConfigured() const {
        return (youtubeEnabled() && !youtubeKey().isEmpty()) ||
               (twitchEnabled() && !twitchKey().isEmpty()) ||
               (kickEnabled() && !kickKey().isEmpty());
    }
    QString activePlatforms() const;
    QString youtubeKey() const {
        const QString k = m_config.value("YOUTUBE_KEY").toString().trimmed();
        return !k.isEmpty() ? k : m_config.value("STREAM_KEY").toString().trimmed();
    }
    bool youtubeEnabled() const {
        return m_config.value("YOUTUBE_ENABLED", "true").toString() != "false";
    }
    QString twitchKey() const {
        return m_config.value("TWITCH_KEY").toString().trimmed();
    }
    bool twitchEnabled() const {
        return m_config.value("TWITCH_ENABLED", "false").toString() == "true";
    }
    QString kickKey() const {
        return m_config.value("KICK_KEY").toString().trimmed();
    }
    QString kickUrl() const {
        return m_config.value("KICK_URL", "rtmps://fa723fc1b171.global-contribute.live-video.net/app").toString().trimmed();
    }
    bool kickEnabled() const {
        return m_config.value("KICK_ENABLED", "false").toString() == "true";
    }
    // What the user reads when something goes wrong: a command's own stderr
    // leads; the recorder's watchdog reason (written to state.json by the CLI)
    // follows. One honest line, no stack dumps.
    QString lastError() const {
        return m_commandError.isEmpty() ? m_stateError : m_commandError;
    }

    QString streamKey() const { return youtubeKey(); }
    QString streamResolution() const { return m_config.value("STREAM_RESOLUTION", "auto").toString(); }
    QString audioSystem() const { return m_config.value("AUDIO_SYSTEM", "auto").toString(); }
    QString audioMic() const { return m_config.value("AUDIO_MIC", "auto").toString(); }
    bool micEnabled() const { return m_config.value("MIC_ENABLED", "true").toString() != "false"; }
    QString videoCodec() const { return m_config.value("VIDEO_CODEC", "h264").toString(); }
    int bitrate() const { return m_config.value("VIDEO_BITRATE", "4500").toString().toInt(); }
    QString screenSharpness() const { return m_config.value("SCREEN_SHARPNESS", "off").toString(); }
    bool camOnStart() const { return m_config.value("CAM_ON_START", "false").toString() == "true"; }
    bool cpuFallback() const { return m_config.value("CPU_FALLBACK", "true").toString() != "false"; }
    QVariantList systemOutputs() const { return m_systemOutputs; }
    QVariantList microphones() const { return m_microphones; }

    Q_INVOKABLE void toggleStream();
    Q_INVOKABLE void startStream();
    Q_INVOKABLE void stopStream();
    Q_INVOKABLE void startTest();
    Q_INVOKABLE void openTestFile();
    Q_INVOKABLE void toggleCam();
    Q_INVOKABLE void cycleCamShape();
    Q_INVOKABLE void setCamShape(const QString &shape);
    Q_INVOKABLE void setCamCorner(const QString &corner);
    Q_INVOKABLE void setCamFlip(bool flip);
    Q_INVOKABLE void togglePrivacy();
    Q_INVOKABLE void setPrivacyActive(bool active);
    Q_INVOKABLE void setPrivacyMode(const QString &mode);
    Q_INVOKABLE void openYouTubeStudio();
    Q_INVOKABLE void openTwitchDashboard();
    Q_INVOKABLE void openKickDashboard();
    Q_INVOKABLE void togglePlatform(const QString &platform);
    Q_INVOKABLE void setSetting(const QString &key, const QVariant &value);
    Q_INVOKABLE void refreshAudioDevices();
    Q_INVOKABLE void cleanupOnClose();
    Q_INVOKABLE void stopAndQuit();

    // state file and config parsing, exposed for tests
    static QJsonObject parseJson(const QByteArray &data);
    static QVariantMap parseConfig(const QByteArray &data);
    static QString formatElapsed(long long startedAtMs, long long nowMs);

signals:
    void stateChanged();
    void configChanged();
    void audioDevicesChanged();
    void busyChanged();
    void lastErrorChanged();

private:
    void setAppRunningState(bool running);
    QString basePath(const char *xdgName, const char *fallback);
    void armWatch(const QString &path);
    void reloadState();
    void reloadConfig();
    void runCommand(const QStringList &args, const QString &niceError);
    QString cliPath() const;
    void applyState(const QJsonObject &state);

    QString m_statePath, m_configPath, m_cli;
    QFileSystemWatcher m_watcher;
    QTimer m_debounce, m_elapsedTimer;

    bool m_streaming = false;
    bool m_cleanedUp = false;
    long long m_startedAt = 0;
    QString m_elapsed, m_mode, m_output;
    bool m_camVisible = false, m_starting = false, m_camFlip = true;
    bool m_privacyActive = false;
    QString m_privacyMode = "blur";
    QString m_camShape = "16:9", m_stateError, m_commandError;
    QVariantMap m_config;
    QVariantList m_systemOutputs, m_microphones;
    QProcess m_audioProbe;
};
