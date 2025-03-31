import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rte/flutter_rte.dart';
import 'package:flutter_rte/src/utils/utils.dart';
import 'package:meta/meta.dart';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:flutter_rte/src/controllers/editor_controller_mixin_stub.dart'
    if (dart.library.io) 'package:flutter_rte/src/controllers/editor_controller_mixin_native.dart'
    if (dart.library.html) 'package:flutter_rte/src/controllers/editor_controller_mixin_web.dart';

part 'event_sink_extension.dart';
part 'dictation_extension.dart';

/// Controller for web
class HtmlEditorController with ChangeNotifier, PlatformSpecificMixin {
  HtmlEditorController({
    // this.processInputHtml = true,
    this.processNewLineAsBr = false,
    this.processOutputHtml = true,
    HtmlEditorOptions? editorOptions,
    HtmlToolbarOptions? toolbarOptions,
    HtmlStylingOptions? stylingOptions,
    Callbacks? callbacks,
    this.context,
  })  : callbacks = callbacks ?? Callbacks(),
        editorOptions = editorOptions ?? HtmlEditorOptions(),
        toolbarOptions = toolbarOptions ?? HtmlToolbarOptions(),
        stylingOptions = stylingOptions ??
            HtmlStylingOptions(
                blockTagAttributes:
                    HtmlTagAttributes(inlineStyle: 'text-align:justify;')) {
    viewId = getRandString(10).substring(0, 14);
    if (editorOptions?.initialText?.isNotEmpty ?? false) {
      _buffer = editorOptions?.initialText ?? '';
    }
  }

  /// This context is used __only__ if you need to provide a context other than
  /// the one the Editor will get by default.
  BuildContext? context;

  /// Defines options for the html editor
  HtmlEditorOptions editorOptions;

  /// Defines options for the editor toolbar
  HtmlToolbarOptions toolbarOptions;

  /// Defines CSS styles for various components and whe
  HtmlStylingOptions stylingOptions;

  //late List<Plugins> plugins;

  /// Puts editor in read-only mode, hiding its toollbar
  bool isReadOnly = false;

  /// If enabled - shows microphone icon and allows to use dictation within
  /// the editor
  bool enableDictation = true;

  /// whether the interface is initialized successfully
  bool get initialized => _initialized;
  // ignore: prefer_final_fields
  bool _initialized = false;

  /// Sometimes, when using MVVM/MVC design patterns, you may want to
  /// keep your controller in the root provider or notifier.
  /// In this case, when UI component gets destroyed you will want
  /// your controlller to be aware of that.
  /// This `deinitialize` method does just that.
  ///
  /// It's called automatically when the editor widget is being disposed,
  /// so there's no need to call it explicitly outside.
  void deinitialize() => _initialized = false;

  /// used internally to tell event sink
  /// to ignore incoming onInit from the editor
  /// and replace it with onChanged instead
  bool _blockInitCallback = false;

  /// read only mode
  @internal
  bool isDisabled = false;

  ///
  bool hasFocus = false;

  ///
  @internal
  FocusNode? focusNode;

  /// Toolbar widget state to call various methods. For internal use only.
  ToolbarWidgetState? toolbar;

  /// Sets & activates Summernote's callbacks. See the functions available in
  /// [Callbacks] for more details.
  Callbacks callbacks;

  ///
  GlobalKey toolbarKey = GlobalKey();

  @internal
  double get verticalPadding =>
      (editorOptions.padding?.top ?? 0) + (editorOptions.padding?.bottom ?? 0);

  /// The absolute minimum possible height including one line of text
  /// plus top and bottom padding
  double _contentHeight = 64;

  /// height occupied by the content section of the editor
  double get contentHeight => _contentHeight;
  set contentHeight(double height) {
    if (contentHeight != height && autoAdjustHeight) {
      _contentHeight = height + verticalPadding;
      recalculateTotalHeight();
    }
  }

  ///
  void recalculateTotalHeight() {
    if (toolbarHeight != null) {
      totalHeight.value = toolbarHeight! + _contentHeight;
    } else {
      totalHeight.value = _contentHeight + verticalPadding;
    }
    notifyListeners();
  }

  /// toolbar widget height
  double? get toolbarHeight => toolbar?.toolbarActualHeight;

  /// total height of the editor = content height + toolbar height
  ValueNotifier<double> totalHeight = ValueNotifier(115);

  /// The editor will automatically adjust its height once the page is loaded to
  /// ensure there is no vertical scrolling or empty space. It will only perform
  /// the adjustment when the editor is the loaded page.
  ///
  /// It will also disable vertical scrolling on the webview, so scrolling on
  /// the webview will actually scroll the rest of the page rather than doing
  /// nothing because it is trying to scroll the webview container.
  ///
  /// The default value is true. It is recommended to leave this as true because
  /// it significantly improves the UX.
  bool get autoAdjustHeight => editorOptions.height == null;

  /// Determines whether text processing should happen on input HTML, e.g.
  /// whether a new line should be converted to a <br>.
  ///
  /// The default value is true.
  // final bool processInputHtml;

  /// Determines whether newlines (\n) should be written as <br>. This is not
  /// recommended for HTML documents.
  ///
  /// The default value is false.
  final bool processNewLineAsBr;

  /// Determines whether empty paragraph should be disregarded as a value,
  /// e.g. whether `<p><br></p>` is returned as "". Editor uses that HTML
  /// as the initial HTML for an opening paragraph (when no text has been
  /// entered in the editor).
  ///
  /// The default value is `true`.
  final bool processOutputHtml;

  /// Internally tracks the character count in the editor
  int _characterCount = 0;

  /// Gets the current character count
  // ignore: unnecessary_getters_setters
  int get characterCount => _characterCount;

  /// Sets the current character count. Marked as internal method - this should
  /// not be used outside of the package itself.
  // ignore: unnecessary_getters_setters
  set characterCount(int count) => _characterCount = count;

  ///
  final Map<String, Completer> _openRequests = {};

  /// is dictation available
  bool get sttAvailable => SpeechToText().isAvailable;

  /// is dictation running?
  bool isRecording = false;
  @internal
  void setIsRecording(bool value) {
    isRecording = value;
    notifyListeners();
  }

  /// Dictation result buffer
  String sttBuffer = '';

  @internal
  void setSttBuffer(String value) {
    sttBuffer = value;
    notifyListeners();
  }

  /// Fault thrown by the editor. Null if there is no fault.
  Exception? fault;

  @internal
  void setFault(Exception e) {
    fault = e;
    notifyListeners();
  }

  /// is there a fault? If there is, the editor will show an error message
  /// instead of the editor itself. The "Ok" button will reset the fault.
  bool get hasFault => fault != null;

  /// resets the fault and hides the error message if there is one
  void resetFault() {
    fault = null;
    notifyListeners();
  }

  // ignore: prefer_final_fields
  String _buffer = '';

  /// Gets the current content of the editor.
  ///
  /// If the editor only has one empty paragraph- it will return an empty string.
  String get content {
    // do not count the empty paragraph as a valuable content.
    // this is needed to properly evaluate the `contentIsEmpty` property
    if (processOutputHtml && textHasNoValue(_buffer)) {
      return '';
    }

    return _buffer;
  }

  /// Checks if the editor is empty
  bool get contentIsEmpty => content.isEmpty;

  /// Checks if the editor is not empty
  bool get contentIsNotEmpty => content.isNotEmpty;

  /// Sets the initial text of the editor. This is useful when you want to
  /// initialize the editor with some text.
  void setInitialText(String text) {
    _buffer = text;
    editorOptions.initialText = text;
    //
  }

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  // - - - - - - - - METHODS API - - - - - - - - - - - - - - - - - - - - - //
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  /// Sets the focus to the editor.
  void setFocus() {
    if (!isDisabled && !isReadOnly) {
      evaluateJavascript(data: {'type': 'toIframe: setFocus'});
      focusNode?.requestFocus();
    }
  }

  /// Scrolls the editor to the position of the cursor
  void scrollToCursor() =>
      evaluateJavascript(data: {'type': 'toIframe: scrollToCursor'});

  /// Move the cursor to the end of the editor
  Future<String> moveCursorToEnd() async {
    // if there is already a request for the text, complete it with an error
    if (_openRequests.keys.contains('moveCursorToEnd')) {
      _openRequests['moveCursorToEnd']
          ?.completeError('Duplicate [moveCursorToEnd] request');
      _openRequests.remove('moveCursorToEnd');
    }
    _openRequests.addEntries({'moveCursorToEnd': Completer<String>()}.entries);
    unawaited(evaluateJavascript(data: {'type': 'toIframe: moveCursorToEnd'}));
    return _openRequests['moveCursorToEnd']?.future as Future<String>;
  }

  /// Move the cursor to the start of the editor
  Future<String> moveCursorToStart() async {
    // if there is already a request for the text, complete it with an error
    if (_openRequests.keys.contains('moveCursorToStart')) {
      _openRequests['moveCursorToStart']
          ?.completeError('Duplicate [moveCursorToStart] request');
      _openRequests.remove('moveCursorToStart');
    }
    _openRequests
        .addEntries({'moveCursorToStart': Completer<String>()}.entries);
    unawaited(
        evaluateJavascript(data: {'type': 'toIframe: moveCursorToStart'}));
    return _openRequests['moveCursorToStart']?.future as Future<String>;
  }

  /// Clears the focus from the webview
  void clearFocus() =>
      evaluateJavascript(data: {'type': 'toIframe: clearFocus'});

  /// disables the Html editor
  Future<void> disable() async {
    if (isDisabled) return;
    toolbar?.disable();
    await evaluateJavascript(data: {'type': 'toIframe: disable'});
    //await recalculateContentHeight();
    isDisabled = true;
    notifyListeners();
  }

  /// enables the Html editor
  Future<void> enable() async {
    toolbar?.enable();
    await evaluateJavascript(data: {'type': 'toIframe: enable'});
    await recalculateContentHeight();
    isDisabled = false;
    notifyListeners();
    setFocus();
  }

  /// Undoes the last action
  void undo() => evaluateJavascript(data: {'type': 'toIframe: undo'});

  /// Redoes the last action
  void redo() => evaluateJavascript(data: {'type': 'toIframe: redo'});

  /// Sets the text of the editor.
  Future<void> setText(String text) async {
    _buffer = text;
    if (!initialized) {
      // if the editor is not initialized yet, set the _buffer value
      // and return
      return;
    }
    if (kIsWeb) {
      await evaluateJavascript(
          data: {'type': 'toIframe: setText', 'text': text});
    } else {
      // on native platform - reload page with new value
      await reloadContent();
    }
    await recalculateContentHeight();
  }

  /// Insert text at the end of the current HTML content in the editor
  /// Note: This method should only be used for plaintext strings
  Future<void> insertText(String text) async {
    await evaluateJavascript(
        data: {'type': 'toIframe: insertText', 'text': text});
  }

  /// Insert HTML at the position of the cursor in the editor
  /// Note: This method should not be used for plaintext strings
  Future<void> insertHtml(String html) async {
    await evaluateJavascript(
        data: {'type': 'toIframe: insertHtml', 'html': _processHtml(html)});
  }

  /// Gets the text from the editor and returns it as a [String].
  Future<String> getText() async {
    // if there is already a request for the text, complete it with an error
    if (_openRequests.keys.contains('getText')) {
      _openRequests['getText']?.completeError('Duplicate [getText] request');
      _openRequests.remove('getText');
    }
    _openRequests.addEntries({'getText': Completer<String>()}.entries);
    unawaited(evaluateJavascript(data: {'type': 'toIframe: getText'}));
    return _openRequests['getText']?.future as Future<String>;
  }

  /// Clears the editor of any text.
  Future<void> clear() async {
    await evaluateJavascript(data: {'type': 'toIframe: clear'});
  }

  /// toggles the codeview in the Html editor
  void toggleCodeView() {
    evaluateJavascript(data: {'type': 'toIframe: toggleCode'});
  }

  /// Gets the selected text from the editor and returns it as a [String].
  Future<String> getSelectedText() async {
    // if there is already a request for the selected text, return its future
    if (_openRequests.keys.contains('getSelectedTextHtml')) {
      _openRequests['getSelectedTextHtml']
          ?.completeError('Duplicate [getSelectedTextHtml] request');
      _openRequests.remove('getSelectedTextHtml');
    }
    _openRequests
        .addEntries({'getSelectedTextHtml': Completer<String>()}.entries);
    unawaited(
        evaluateJavascript(data: {'type': 'toIframe: getSelectedTextHtml'}));
    return _openRequests['getSelectedTextHtml']!.future as Future<String>;
  }

  /// Insert a link at the position of the cursor in the editor
  Future<void> insertLink(String text, String url, bool isNewWindow) async {
    await evaluateJavascript(data: {
      'type': 'toIframe: makeLink',
      'text': text,
      'url': url,
      'isNewWindow': isNewWindow
    });
  }

  ///
  Future<void> removeLink() async {
    await evaluateJavascript(data: {'type': 'toIframe: removeLink'});
  }

  /// Recalculates the height of the editor to remove any vertical scrolling.
  /// This method will not do anything if [autoAdjustHeight] is turned off.
  Future<void> recalculateContentHeight() async {
    await evaluateJavascript(data: {
      'type': 'toIframe: getHeight',
    });
  }

  /// A function to quickly call a document.execCommand function in a readable format
  Future<void> execCommand(String command, {String? argument}) async {
    await evaluateJavascript(data: {
      'type': 'toIframe: execCommand',
      'command': command,
      'argument': argument
    });
  }

  Future<void> updateToolbar() async {
    await evaluateJavascript(data: {
      'type': 'toIframe: updateToolbar',
    });
  }

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - //

  /// Helper function to process input html
  String _processHtml(String html) {
    if (processNewLineAsBr) {
      html = html.replaceAll('\n', '<br />');
    } else {
      html = html.replaceAll('\n', '&#10;').replaceAll('\r', '&#13;');
    }
    html = html.replaceAll('<br>', '<br />');
    html = html.replaceAll(
        "'", '&#39;'); // &apos; is not supported in HTML4, use &#39; instead.
    return html;
  }

  /// Initialization of native UI component
  /// the `init` method is pulled from platform-specific mixin
  /// and is different for each platform
  Future<void> initEditor(BuildContext initBC) async {
    if (initialized) throw Exception('Already initialized');
    await init(initBC, _contentHeight, this);

    // on web - we need to set the `_initialized` flag here
    // and notify listeners
    if (kIsWeb) {
      _initialized = true;
      notifyListeners();
    }
  }

  /// This method compiles HTML document based on various controller settings
  Future<String> getInitialContent() async {
    var textColor = stylingOptions.textColorCssString(context!);
    var initScript = '''const viewId = '$viewId';
    const blockTag = '${stylingOptions.blockTag}';
    ''';
    if (kIsWeb) {
      initScript += '''
const isNativePlatform = false;
''';
    } else {
      initScript += '''
const isNativePlatform = true;
''';
    }

    var htmlString = await rootBundle.loadString(filePath);
    htmlString =
        htmlString.replaceFirst('/*---- Init Script ----*/', initScript);

    var readonly =
        'richTextBox.spellcheck = ${isDisabled || isReadOnly ? 'false' : 'true'};\n'
        'richTextBox.contentEditable = ${isDisabled || isReadOnly ? 'false' : 'true'};\n';
    htmlString = htmlString.replaceFirst('/*---- Read Only ----*/', readonly);

    /// if no explicit `height` is provided - hide the scrollbar as the
    /// container height will always adjust to the document height.
    /// If the height is set - add padding for the boxed layouts.
    var hideScrollbarCss = '';
    if (editorOptions.height == null && !editorOptions.expandFullHeight) {
      hideScrollbarCss = '''
  ::-webkit-scrollbar { width: 0px; height: 0px; }
  body { color: $textColor; }
''';
    } else {
      hideScrollbarCss = '''
  body { padding: .5em 1em; color: $textColor; }
''';
    }

    htmlString = htmlString.replaceFirst(
        '/*---- Hide Scrollbar ----*/', hideScrollbarCss);

    htmlString = htmlString.replaceFirst(
        '/*---- Root Stylesheet ----*/', stylingOptions.getRootStyleText);

    // if `_buffer` is not empty during init ( `setText()` called headlessly )
    // - use `_buffer` as initial content,
    // otherwise use the `initialText` from the options, or empty string
    htmlString = htmlString.replaceFirst(
        '<squirecontent>',
        _processHtml(
            _buffer.isNotEmpty ? _buffer : editorOptions.initialText ?? ''));

    htmlString = htmlString.replaceFirst(
        '/*---- Squire Config ----*/', stylingOptions.options);

    return htmlString;
  }

  /// On native platform html injection is restricted, so we need
  /// to reload the page with new content in it. After the page is loaded,
  /// we need to prevent onInit callback and call onChaged instead.
  Future<void> reloadContent() async {
    _blockInitCallback = true;
    await editorController.loadHtmlString(await getInitialContent());
  }
}
