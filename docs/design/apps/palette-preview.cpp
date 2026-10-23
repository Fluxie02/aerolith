// UI-010 evidence fixture, not a shipped settings app or installer.
// Build in the existing dev image; no additional packages. See README.md.
#include <QtWidgets>

int main(int argc, char **argv) {
    QApplication app(argc, argv);
    app.setApplicationName("aerolith-palette-preview");
    app.setDesktopFileName("aerolith-palette-preview");
    if (argc != 4) qFatal("usage: palette-preview SCHEME QSS PALETTE-JSON");
    app.setStyle(QStyleFactory::create("Fusion"));
    QSettings scheme(QString::fromLocal8Bit(argv[1]), QSettings::IniFormat);
    QPalette palette;
    QJsonObject evidence;
    const QPair<QString, QPalette::ColorGroup> groups[] = {
        {"active", QPalette::Active}, {"inactive", QPalette::Inactive},
        {"disabled", QPalette::Disabled}
    };
    for (const auto &group : groups) {
        const auto values = scheme.value("ColorScheme/" + group.first + "_colors").toStringList();
        if (values.size() < QPalette::NColorRoles) qFatal("incomplete colour group");
        QJsonArray actual;
        for (int role = 0; role < QPalette::NColorRoles; ++role) {
            const QColor color(values.at(role));
            if (!color.isValid() || color.alpha() != 255) qFatal("invalid or translucent colour");
            palette.setColor(group.second, QPalette::ColorRole(role), color);
            actual.append(palette.color(group.second, QPalette::ColorRole(role)).name(QColor::HexArgb));
        }
        evidence[group.first] = actual;
    }
    app.setPalette(palette);
    app.setFont(QFont("Inter", 11));
    QFile qss(QString::fromLocal8Bit(argv[2]));
    if (!qss.open(QIODevice::ReadOnly)) qFatal("cannot read shape layer");
    app.setStyleSheet(QString::fromUtf8(qss.readAll()));
    evidence["qtVersion"] = qVersion();
    evidence["roles"] = QPalette::NColorRoles;
    evidence["baseStyle"] = "Fusion";
    evidence["styleClass"] = app.style()->metaObject()->className();
    evidence["requestedFont"] = app.font().family();
    evidence["resolvedFont"] = QFontInfo(app.font()).family();

    QMainWindow window;
    window.setWindowTitle("AEROLITH · Qt Widgets palette preview");
    window.resize(850, 620);
    auto *body = new QWidget;
    auto *layout = new QVBoxLayout(body);
    layout->setContentsMargins(24, 18, 24, 20);
    layout->setSpacing(16);
    auto *title = new QLabel("Application appearance");
    QFont heading = app.font(); heading.setPointSize(21); title->setFont(heading);
    layout->addWidget(title);
    layout->addWidget(new QLabel("Stock Fusion · native Qt 6 Widgets · palette and rounded controls"));
    auto *tabs = new QTabWidget;
    auto *page = new QWidget;
    auto *pageLayout = new QVBoxLayout(page);
    pageLayout->setContentsMargins(18, 18, 18, 18);
    pageLayout->setSpacing(14);
    auto *form = new QFormLayout;
    auto *name = new QLineEdit("AEROLITH / Limb");
    form->addRow("Profile", name);
    auto *placeholder = new QLineEdit;
    placeholder->setPlaceholderText("Placeholder text uses the opaque secondary colour");
    form->addRow("Description", placeholder);
    auto *combo = new QComboBox;
    combo->addItems({"Saturated", "Insane"});
    form->addRow("Shell intensity", combo);
    auto *spin = new QSpinBox; spin->setRange(8, 24); spin->setValue(11); spin->setSuffix(" pt");
    form->addRow("Interface font size", spin);
    pageLayout->addLayout(form);
    auto *tree = new QTreeWidget;
    tree->setHeaderLabels({"Palette role", "Source colour"});
    const QStringList labels = {"Window · smoked surface", "View · obsidian", "Selection · phosphor", "Text · instrument white"};
    const QStringList colors = {"#1b282b", "#0d1215", "#ceebac", "#edf3f5"};
    for (int i = 0; i < labels.size(); ++i) new QTreeWidgetItem(tree, {labels[i], colors[i]});
    tree->setAlternatingRowColors(true);
    tree->setColumnWidth(0, 390);
    tree->setCurrentItem(tree->topLevelItem(2));
    tree->setMinimumHeight(145);
    pageLayout->addWidget(tree);
    auto *check = new QCheckBox("Native checkbox and slider indicators"); check->setChecked(true);
    pageLayout->addWidget(check);
    auto *slider = new QSlider(Qt::Horizontal); slider->setValue(62); pageLayout->addWidget(slider);
    tabs->addTab(page, "Palette & controls");
    auto *notes = new QLabel("This is a rendering fixture. No audio, network or system settings are changed.");
    notes->setWordWrap(true); tabs->addTab(notes, "Preview scope");
    layout->addWidget(tabs);
    auto *buttons = new QHBoxLayout;
    auto *disabled = new QPushButton("Unavailable"); disabled->setEnabled(false); buttons->addWidget(disabled);
    buttons->addStretch();
    auto *files = new QPushButton("File dialog…"); buttons->addWidget(files);
    auto *apply = new QPushButton("Focus preview"); apply->setDefault(true); buttons->addWidget(apply);
    layout->addLayout(buttons);
    QObject::connect(files, &QPushButton::clicked, [&window] {
        auto *dialog = new QFileDialog(&window, "Native Qt file picker · preview", "/src/themes");
        dialog->setOption(QFileDialog::DontUseNativeDialog);
        dialog->setAttribute(Qt::WA_DeleteOnClose);
        dialog->setFileMode(QFileDialog::ExistingFile);
        dialog->resize(790, 510);
        dialog->open();
    });
    window.setCentralWidget(body);
    QObject::connect(&app, &QApplication::focusChanged, [](QWidget *, QWidget *now) {
        qInfo() << "focus:" << (now ? now->metaObject()->className() : "none");
    });
    window.show();
    apply->setFocus(Qt::TabFocusReason);
    placeholder->ensurePolished();
    const auto placeholderColor = placeholder->palette().color(QPalette::Active, QPalette::PlaceholderText);
    evidence["widgetPlaceholderText"] = placeholderColor.name(QColor::HexArgb);
    if (placeholderColor != palette.color(QPalette::Active, QPalette::PlaceholderText))
        qFatal("stylesheet changed the placeholder palette");
    QFile json(QString::fromLocal8Bit(argv[3]));
    if (!json.open(QIODevice::WriteOnly)) qFatal("cannot write evidence");
    json.write(QJsonDocument(evidence).toJson());
    json.close();
    const auto stage = qEnvironmentVariable("AEROLITH_PREVIEW_STAGE");
    if (stage == "selection") {
        QTimer::singleShot(500, name, [name] {
            name->setFocus(Qt::TabFocusReason);
            name->selectAll();
            qInfo() << "preview selection:" << name->selectedText();
        });
    } else if (stage == "files") {
        QTimer::singleShot(500, files, [files] { files->click(); });
    }
    return app.exec();
}
