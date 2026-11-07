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
