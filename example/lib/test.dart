import 'package:material_ui/material_ui.dart';
import 'package:flutter_rte/flutter_rte.dart';

class Test extends StatefulWidget {
  const Test({Key? key}) : super(key: key);

  @override
  State<Test> createState() => _TestState();
}

class _TestState extends State<Test> {
  late final HtmlEditorController textEdtController;

  @override
  void initState() {
    super.initState();
    textEdtController = HtmlEditorController(
      editorOptions: HtmlEditorOptions(
        hint: "Your text here...",
        initialText: "<p>Example with custom toolbar options</p>",
      ),
    );
    textEdtController.toolbarOptions = HtmlToolbarOptions(
      renderSeparatorWidget: true,
      defaultToolbarButtons: const [
        FontButtons(
            strikethrough: false, superscript: false, subscript: false),
        ColorButtons(),
        ParagraphButtons(
            textDirection: false, lineHeight: false, caseConverter: false),
        FontSettingButtons(fontSizeUnit: false),
        ListButtons(listStyles: false),
        InsertButtons(),
        OtherButtons(copy: false, paste: false),
      ],
      toolbarPosition: ToolbarPosition.aboveEditor,
      toolbarType: ToolbarType.nativeExpandable,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test')),
      body: SafeArea(
        child: HtmlEditor(
          expandFullHeight: true,
          controller: textEdtController,
        ),
      ),
    );
  }
}
