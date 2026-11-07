#include "backend.h"
#include "version.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QStandardPaths>
#include <QStringList>
#include <QUrl>

Backend::Backend(const QString &statePath, const QString &configPath, const QString &cli, QObject *parent)
    : QObject(parent) {
    const QString stateHome = basePath("XDG_STATE_HOME", "/.local/state");
    m_statePath = !statePath.isEmpty() ? statePath : stateHome + "/omastream/state.json";
    const QString configHome = basePath("XDG_CONFIG_HOME", "/.config");
    m_configPath = !configPath.isEmpty() ? configPath : configHome + "/omastream/config.env";
    m_cli = !cli.isEmpty() ? cli : cliPath();

    m_debounce.setSingleShot(true);
    m_debounce.setInterval(80);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_debounce.start(); });
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] { m_debounce.start(); });
    connect(&m_debounce, &QTimer::timeout, this, [this] {
        reloadState();
        reloadConfig();
    });

    reloadState();
    reloadConfig();
    refreshAudioDevices();

    // Ticks elapsed time and syncs state continuously
    m_elapsedTimer.setInterval(500);
    connect(&m_elapsedTimer, &QTimer::timeout, this, [this] {
        reloadState();
        if (m_streaming) {
            m_elapsed = formatElapsed(m_startedAt, QDateTime::currentMSecsSinceEpoch());
            emit stateChanged();
        }
    });
    m_elapsedTimer.start();

    connect(&m_audioProbe, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        if (code != 0 || status != QProcess::NormalExit)
            return;
        const auto sources = QJsonDocument::fromJson(m_audioProbe.readAllStandardOutput()).array();
        QVariantMap autoOutput;
        autoOutput.insert("name", "auto");
        autoOutput.insert("description", tr("Default output"));
        QVariantMap autoMic;
        autoMic.insert("name", "auto");
        autoMic.insert("description", tr("Default microphone"));
        QVariantList outputs{autoOutput};
        QVariantList mics{autoMic};
        for (const auto &v : sources) {
            const auto o = v.toObject();
            const QString name = o.value("name").toString();
            if (name.isEmpty())
                continue;
            QVariantMap row; // desktop sound arrives at a ".monitor" capture; real mics don't
            row.insert("name", name);
            row.insert("description", o.value("description").toString());
            if (name.endsWith(".monitor"))
                outputs.append(row);
            else
                mics.append(row);
        }
        m_systemOutputs = outputs;
        m_microphones = mics;
        emit audioDevicesChanged();
    });
}

QString Backend::basePath(const char *xdgName, const char *fallback) {
    const QString env = qEnvironmentVariable(xdgName);
    if (!env.isEmpty())
        return env;
    return QDir::homePath() + fallback;
}

QString Backend::cliPath() const {
    // An explicit env wins, then the installed CLI, then the checkout's
    // cli/omastream for developer runs straight from the build directory.
    const QString env = qEnvironmentVariable("OMASTREAM_CLI");
    if (!env.isEmpty())
        return env;
    const QString installed = QStandardPaths::findExecutable("omastream-cli");
    if (!installed.isEmpty())
        return installed;
    const QString homeBin = QDir::homePath() + "/.local/bin/omastream-cli";
    if (QFile::exists(homeBin))
        return homeBin;
    const QDir checkout = QDir(QCoreApplication::applicationDirPath() + "/..");
    return checkout.absoluteFilePath("cli/omastream");
}

void Backend::armWatch(const QString &path) {
    // The CLI replaces both files with atomic renames, which drops the watch
    // on the file itself, so also watch ancestors and re-arm each reload.
    QString ancestor = path;
    while (!QFileInfo::exists(ancestor) && ancestor != "/")
        ancestor = QFileInfo(ancestor).absolutePath();
    for (const auto &dir : QStringList{ancestor, QFileInfo(ancestor).absolutePath()}) {
        if (!dir.isEmpty() && QFileInfo::exists(dir) && !m_watcher.directories().contains(dir))
            m_watcher.addPath(dir);
    }
    if (QFileInfo::exists(path) && !m_watcher.files().contains(path))
        m_watcher.addPath(path);
}

QJsonObject Backend::parseJson(const QByteArray &data) {
    return QJsonDocument::fromJson(data).object();
}

QVariantMap Backend::parseConfig(const QByteArray &data) {
    QVariantMap out;
    const QStringList lines = QString::fromUtf8(data).split(u'\n');
    for (const QString &line : lines) {
        const qsizetype eq = line.indexOf(u'=');
        if (eq < 1)
            continue;
        QString key = line.left(eq).trimmed();
        if (key.size() >= 2 && ((key.startsWith(u'"') && key.endsWith(u'"')) ||
                                (key.startsWith(u'\'') && key.endsWith(u'\''))))
            key = key.mid(1, key.size() - 2);
        QString value = line.mid(eq + 1);
        if (key.startsWith(u'#'))
            continue; // a whole-line comment that happens to carry '=' is not a key
        // Inline comments trail values — but a '#' inside quotes is data
        // (stream keys are never commented, yet they can carry odd signs).
        QString kept;
        QChar open;
        bool escaped = false;
        for (const QChar c : value) {
            if (escaped) {
                escaped = false;
            } else if (c == u'\\') {
                escaped = true;
            } else if (open.isNull() && (c == u'"' || c == u'\'')) {
                open = c;
            } else if (c == open) {
                open = QChar();
            } else if (open.isNull() && c == u'#') {
                break;
            }
            kept.append(c);
        }
        value = kept;
        value = value.trimmed();
        while (value.size() >= 2 && ((value.startsWith(u'"') && value.endsWith(u'"')) ||
                                     (value.startsWith(u'\'') && value.endsWith(u'\''))))
            value = value.mid(1, value.size() - 2);
        if (!key.isEmpty())
            out.insert(key, value);
    }
    return out;
}

QString Backend::formatElapsed(long long startedAtMs, long long nowMs) {
    long long s = (nowMs - startedAtMs) / 1000;
    if (s < 0)
        s = 0;
    const long long h = s / 3600, m = (s % 3600) / 60, sec = s % 60;
    const auto two = [](long long v) { return QStringLiteral("%1").arg(v, 2, 10, QLatin1Char('0')); };
    if (h > 0)
        return QString("%1:%2:%3").arg(h).arg(two(m), two(sec));
    return QString("%1:%2").arg(m).arg(two(sec));
}

void Backend::reloadState() {
    QFile file(m_statePath);
    if (!file.open(QIODevice::ReadOnly)) {
        if (m_streaming) {
            m_streaming = false;
            m_starting = false;
            emit stateChanged();
            emit busyChanged();
        }
        armWatch(m_statePath);
        return;
    }
    armWatch(m_statePath);
    applyState(parseJson(file.readAll()));
}
void Backend::applyState(const QJsonObject &state) {
    const bool streaming = state.value("streaming").toBool();
    const long long startedAt = static_cast<long long>(state.value("startedAt").toDouble());
    const QString mode = state.value("mode").toString("stream");
    const QString output = state.value("output").toString();
    const auto cam = state.value("cam").toObject();
    const bool camVisible = cam.value("visible").toBool();
    const QString camShape = cam.value("shape").toString("16:9");

    const bool stopped = m_streaming && !streaming;

    m_streaming = streaming;
    m_startedAt = startedAt;
    m_mode = mode;
    m_output = output;
    m_camVisible = camVisible;
    m_camShape = camShape;

    // The bubble preview yields the device while gsr composites the camera,
    // which the state's flip mirrors; config.env is the fallback before that.
    if (cam.value("flip").isBool())
        m_camFlip = cam.value("flip").toBool();

    // The recorder's watchdog speaks through state.json when it dies alone.
    const QString reason = state.value("lastError").toString();
    QString nextError;
    if (!streaming && !reason.isEmpty())
        nextError = reason;

    m_elapsed = streaming ? formatElapsed(m_startedAt, QDateTime::currentMSecsSinceEpoch()) : QString();
    m_starting = false;
    if (nextError != m_stateError) {
        m_stateError = nextError;
        emit lastErrorChanged();
    }
    if (stopped && m_stateError.isEmpty() && !m_commandError.isEmpty()) {
        m_commandError.clear(); // a clean stop clears any stale complaint
        emit lastErrorChanged();
    }
    emit stateChanged();
    emit busyChanged();
}

void Backend::reloadConfig() {
    QFile file(m_configPath);
    if (file.open(QIODevice::ReadOnly)) {
        const QVariantMap fresh = parseConfig(file.readAll());
        // only speak when something actually changed — every CLI write lands
        // here, and resetting the selects each time would feel like the app
        // keeps erasing what you just typed
        if (fresh != m_config) {
            m_config = fresh;
            emit configChanged();
        }
        armWatch(m_configPath);
    } else {
        armWatch(m_configPath);
    }
}

QString Backend::statusLine() const {
    if (!m_streaming)
        return tr("Not streaming");
    if (m_mode == "file")
        return tr("Recording test · %1").arg(m_elapsed);
    return tr("LIVE · %1").arg(m_elapsed);
}

void Backend::runCommand(const QStringList &args, const QString &niceError) {
    if (!m_commandError.isEmpty()) {
        m_commandError.clear(); // a fresh try starts with a clean conscience
        emit lastErrorChanged();
    }
    auto *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this, [this, niceError](int code, QProcess::ExitStatus status) {
        auto *proc = qobject_cast<QProcess *>(sender());
        if (code != 0 || status != QProcess::NormalExit) {
            m_starting = false;
            emit busyChanged();
            QString stderrText = QString::fromUtf8(proc->readAllStandardError()).trimmed();
            if (stderrText.isEmpty())
                stderrText = QString::fromUtf8(proc->readAllStandardOutput()).trimmed();
            const QStringList lines = stderrText.split(u'\n', Qt::SkipEmptyParts);
            const QString next = !lines.isEmpty()
                ? lines.last().left(180)
                : QString();
            if (!niceError.isEmpty() && next.isEmpty())
                m_commandError = niceError;
            else if (!next.isEmpty())
                m_commandError = next;
            else
                m_commandError = tr("Check YouTube is ready and the stream key is set.");
            emit lastErrorChanged();
        }
        proc->deleteLater();
        reloadState();
        reloadConfig();
        // Settings writes and camera commands land on disk fast; pull them in.
        QTimer::singleShot(150, this, [this] {
            reloadState();
            reloadConfig();
        });
    });
    proc->start(m_cli, args);
}

void Backend::toggleStream() {
    if (m_streaming)
        stopStream();
    else
        startStream();
}

void Backend::startStream() {
    if (m_streaming)
        return;
    m_commandError.clear();
    m_stateError.clear();
    emit lastErrorChanged();
    m_starting = true;
    emit busyChanged();
    runCommand({"start"}, tr("Check YouTube is ready and the stream key is set."));
}

void Backend::stopStream() {
    runCommand({"stop"}, tr("The recorder refused to stop; check the log."));
}

void Backend::startTest() {
    if (m_streaming)
        return;
    m_commandError.clear();
    m_stateError.clear();
    emit lastErrorChanged();
    m_starting = true;
    emit busyChanged();
    runCommand({"test"}, tr("The capture test failed; check the log."));
}

void Backend::openTestFile() {
    QString out = QString::fromLocal8Bit(qgetenv("XDG_STATE_HOME"));
    if (out.isEmpty())
        out = QDir::homePath() + "/.local/state";
    const QString filePath = out + "/omastream/test.flv";
    if (QFile::exists(filePath))
        QDesktopServices::openUrl(QUrl::fromLocalFile(filePath));
    else
        QDesktopServices::openUrl(QUrl::fromLocalFile(out + "/omastream"));
}

void Backend::toggleCam() {
    runCommand(m_camVisible ? QStringList{"cam", "off"} : QStringList{"cam", "on"}, {});
}

void Backend::cycleCamShape() {
    QString next = "circle";
    if (m_camShape == "circle")
        next = "1:1";
    else if (m_camShape == "1:1")
        next = "16:9";
    else
        next = "circle";
    setCamShape(next);
}

void Backend::setCamShape(const QString &shape) {
    if (shape != "circle" && shape != "1:1" && shape != "16:9")
        return;
    runCommand({"cam", "shape", shape}, {});
}

void Backend::setCamFlip(bool flip) {
    setSetting("CAM_FLIP", flip);
}

void Backend::setSetting(const QString &key, const QVariant &value) {
    static const QStringList allowed{
        "STREAM_KEY", "VIDEO_CODEC", "VIDEO_BITRATE", "FPS", "AUDIO_SYSTEM", "AUDIO_MIC",
        "MIC_ENABLED", "CAM_DEVICE", "CAM_FLIP", "CAM_RECORD", "CAM_ON_START",
        "DEFAULT_CAM_SHAPE", "CAM_FIT", "CPU_FALLBACK"};
    if (!allowed.contains(key) || value.isNull())
        return;
    const QString text = value.toString();
    if (text.contains('\n') || text.contains('\'') || text.contains('"')) {
        m_commandError = tr("Not a valid value for %1").arg(key);
        emit lastErrorChanged();
        return;
    }
    runCommand({"config", "set", key, text}, {});
}

void Backend::refreshAudioDevices() {
    if (m_audioProbe.state() != QProcess::NotRunning)
        return;
    const QString pactl = QStandardPaths::findExecutable("pactl");
    if (pactl.isEmpty())
        return;
    m_audioProbe.start(pactl, {"-f", "json", "list", "sources"});
}
