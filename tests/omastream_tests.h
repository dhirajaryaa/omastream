#pragma once

#include <QDir>
#include <QFile>
#include <QTemporaryDir>
#include <QtTest>

#include "backend.h"
#include "theme.h"
#include "translator.h"

class OmastreamTests : public QObject {
    Q_OBJECT

private slots:
    // config.env tolerates inline comments, quotes and junk spacing — the
    // exact shapes gpu users put into the file by hand.
    void parseConfigReadsValues()
    {
        const QVariantMap config = Backend::parseConfig(QByteArray(
            "STREAM_KEY='abc/123#not-a-comment'\n"
            "STREAM_RESOLUTION=1920x1080\n"
            "VIDEO_BITRATE=4500     # kbps, CBR\n"
            " AUDIO_SYSTEM =  device:alsa_output.monitor \n"
            "\"MIC_ENABLED\"=true\n"
            "junk line without equals\n"
            "# a full comment — even carrying = — is not a key\n"
            "CAM_FLIP=\"true\" # quoted\n"));
        QCOMPARE(config.value("STREAM_KEY").toString(), "abc/123#not-a-comment");
        QCOMPARE(config.value("STREAM_RESOLUTION").toString(), "1920x1080");
        QCOMPARE(config.value("VIDEO_BITRATE").toString(), "4500");
        QCOMPARE(config.value("AUDIO_SYSTEM").toString(), "device:alsa_output.monitor");
        QCOMPARE(config.value("MIC_ENABLED").toString(), "true");
        QCOMPARE(config.value("CAM_FLIP").toString(), "true");
        QVERIFY(!config.contains("junk line without equals"));
        QVERIFY(!config.contains("# a full comment — even carrying = — is not a key"));
    }

    void parseMultiPlatformConfig()
    {
        const QVariantMap config = Backend::parseConfig(QByteArray(
            "YOUTUBE_KEY='yt-key-123'\n"
            "YOUTUBE_ENABLED=true\n"
            "TWITCH_KEY='live_twitch_abc'\n"
            "TWITCH_ENABLED=true\n"
            "KICK_KEY='kick_secret_xyz'\n"
            "KICK_URL='rtmps://custom.kick.ingest/app'\n"
            "KICK_ENABLED=false\n"));
        QCOMPARE(config.value("YOUTUBE_KEY").toString(), "yt-key-123");
        QCOMPARE(config.value("YOUTUBE_ENABLED").toString(), "true");
        QCOMPARE(config.value("TWITCH_KEY").toString(), "live_twitch_abc");
        QCOMPARE(config.value("TWITCH_ENABLED").toString(), "true");
        QCOMPARE(config.value("KICK_KEY").toString(), "kick_secret_xyz");
        QCOMPARE(config.value("KICK_URL").toString(), "rtmps://custom.kick.ingest/app");
        QCOMPARE(config.value("KICK_ENABLED").toString(), "false");
    }

    void backendMultiPlatformResolution()
    {
        QTemporaryDir dir;
        const QString confPath = dir.path() + "/config.env";
        const QString statePath = dir.path() + "/state.json";
        write(confPath,
            "YOUTUBE_KEY='yt-123'\n"
            "YOUTUBE_ENABLED=true\n"
            "TWITCH_KEY='tw-456'\n"
            "TWITCH_ENABLED=true\n"
            "KICK_KEY=''\n"
            "KICK_ENABLED=false\n");

        Backend backend(statePath, confPath, "/bin/true");
        QCOMPARE(backend.youtubeKey(), QString("yt-123"));
        QCOMPARE(backend.youtubeEnabled(), true);
        QCOMPARE(backend.twitchKey(), QString("tw-456"));
        QCOMPARE(backend.twitchEnabled(), true);
        QCOMPARE(backend.kickEnabled(), false);
        QCOMPARE(backend.hasAnyPlatformConfigured(), true);
        QCOMPARE(backend.activePlatforms(), QString("YouTube + Twitch"));
    }

    void parseStateKeepsValues()
    {
        const QByteArray stateText =
            "{\"streaming\":true,\"pid\":42,\"startedAt\":1672400000000,"
            "\"mode\":\"stream\","
            "\"output\":\"rtmp://a.rtmp.youtube.com/live2/abcd-efgh\","
            "\"cam\":{\"visible\":true,\"shape\":\"circle\",\"flip\":true}}";
        const QJsonObject state = Backend::parseJson(stateText);
        QCOMPARE(state.value("streaming").toBool(), true);
        QCOMPARE(state.value("pid").toInt(), 42);
        QCOMPARE(state.value("cam").toObject().value("shape").toString(), "circle");
    }

    void formatElapsedClocks()
    {
        QCOMPARE(Backend::formatElapsed(1000, 61000), QString("1:00"));
        QCOMPARE(Backend::formatElapsed(1000, 3661000), QString("1:01:00"));
        // clock skew never shows a negative counter
        QCOMPARE(Backend::formatElapsed(3000, 1000), QString("0:00"));
    }

    void themeFallsBack()
    {
        QTemporaryDir dir;
        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QString("#FFD60A"));
        QCOMPARE(theme.accentForeground(), QString("black"));
    }

    void themeReadsAccent()
    {
        QTemporaryDir dir;
        QDir(dir.path()).mkpath("theme");
        QFile colors(dir.path() + "/theme/colors.toml");
        QVERIFY(colors.open(QIODevice::WriteOnly));
        colors.write("accent = \"#112233\"\n");
        colors.close();

        Theme theme(dir.path());
        QCOMPARE(theme.accent(), QString("#112233"));
        QCOMPARE(theme.accentForeground(), QString("white"));
    }

    void translatorFallsBackToEnglish()
    {
        QTemporaryDir dir;
        Translator translator(dir.path() + "/language", dir.path());
        QCOMPARE(translator.language(), QString("en"));
        QVERIFY(translator.translate("Main", "Save").isNull());
    }

    void translatorFollowsTheLanguageFile()
    {
        QTemporaryDir dir;
        write(dir.path() + "/language", "pt-BR\n");
        write(dir.path() + "/pt.json", R"({"Save": "Guardar", "Open": "Abrir"})");
        write(dir.path() + "/pt-BR.json", R"({"Save": "Salvar"})");

        Translator translator(dir.path() + "/language", dir.path());
        QCOMPARE(translator.language(), QString("pt-BR"));
        QCOMPARE(translator.translate("Main", "Save"), QString("Salvar"));
        QCOMPARE(translator.translate("Main", "Open"), QString("Abrir"));
        QVERIFY(translator.translate("Main", "Quit").isNull());
    }

private:
    static void write(const QString &path, const QByteArray &contents)
    {
        QFile file(path);
        QVERIFY(file.open(QIODevice::WriteOnly));
        file.write(contents);
    }
};
