# Flutter Rich Text Editor

Easy to use WYSIWYG HTML editor for Flutter with built-in voice-to-text.
<br />

### Try it [here](https://flutter-rich-text.web.app/)

<br />

![Flutter Rich Text Editor Web](./media/screen1.jpg)

____


## Under the Hood

This plugin is a reworked [html_editor_enhanced](https://github.com/tneotia/html-editor-enhanced) with a few differences:
 * Improved widget height constraints: 
   - wrap content,
   - expand full height, or 
   - explicit.
 * Summernote and jQuery replaced with [Squire](https://github.com/neilj/Squire) - very popular and well-maintained HTML5 rich text editor library, which provides great flexibility over generated HTML.
 * XSS protection enforced by [DOMPurify](https://github.com/cure53/DOMPurify) - super-fast, uber-tolerant XSS sanitizer for HTML, MathML and SVG.
 * [in_app_webview](https://pub.dev/packages/in_app_webview) replaced with Flutter's own [webview_flutter](https://pub.dev/packages/webview_flutter).
 * Built-in dictation feature powered by [speech_to_text](https://pub.dev/packages/speech_to_text) package (primarily for the web platform)


____


## Basic Implementation

Basic implementation of this editor doesn't require a controller. For simplicity and ease of use, [HtmlEditor] gives you access to the following top-level attributes:

| Field | Type | Description |
| :--- | :----: | :--- |
| `height` | double | sets explicit height of the widget |
| `minHeight` | double | sets minimum height of the widget |
| `expandFullHeight` | bool | sizes widget to take all available height |
| `hint` | String | Displays hint text when the editor is empty |
| `initialValue` | String | initial HTML or text |
| `onChanged` |String  | top-level shortcut to `onChanged` callback of the controller |
| `isReadOnly` | bool | locks the editor and removes the toolbar |
| `enableDictation` | bool | yay or nay to voice-to-text feature |


```Dart
import 'package:flutter_rte/flutter_rte.dart';

// ...

// 1. Define a var to store changes within parent class or a provider etc...
String result = 'Hello world!';

// ...

// 2. Add HtmlEditor to your build method
@override
Widget build(BuildContext context) =>
    HtmlEditor(initalValue: result, onChanged:(s)=> result = s ?? '');

```

____


## Advanced Implementation

To take advantage of the entire API you'll need to create and configure an instance of [HtmlEditorController]. That instance provides access to the following groups of options:

 * **Styling options** group (all things CSS, HTML and sanitizing)
 * **Toolbar options** group (all things toolbar)
 * **Editor options** group (all things editor)

When using the controller, the text of HtmlEditor could be set via `controller.setText()` method. This could be done before or after the controller is attached to the HtmlEditor in the UI. This is useful for MVVM/MVC situations, where the logic is initialized before the UI is built.


Contents of the editor could be tried and accessed syncronously via a getter:
```dart

    if(controller.contentIsNotEmpty){
        Navigator.of(context).pop(controller.content);
    }

```
____

    
### HTML Styling Options

The `stylingOptions` parameter of [HtmlEditorController] class defines the look of generated HTML. Here you can select which tag to use for paragraphs and how your tags are styled.

```Dart

var stylingOptions = HtmlStylingOptions(

    // Adding global style is optional, but could be set in two ways:
    // 1. by providing a CSS string to the parameter `globalStyleSheet`:
    globalStyleSheet: '/* Your CSS string contents of style.css file */',

    // This defines which tag to use for paragraphs.
    // The default value is `p`, however the `div` is also acceptable.
    blockTag: 'p',

    // defines `style` and `class` attributes of a block tag
    blockTagAttributes: HtmlTagAttributes(

        // this is added as inline CSS for every tag
        inlineStyle: 'text-indent:3.5em; text-align:justify;',

        // defines `class` attribute value of every tag
        cssClass: 'my-custom-pgf'),

    // next we can define attributes for other tags (li, ul, ol, a etc):
    li: HtmlTagAttributes(
        inlineStyle: 'margin: .5em 1em  .5em .5em',
        cssClass: 'my-custom-li-class'),

    // ... other HTML tag definitions ... //

    code: HtmlTagAttributes(
        inlineStyle: 'padding: .5em 1em;', cssClass: 'my-custom-li-class'),

    // when sanitizeOnPaste is `true` - editor will sanitize all incoming HTML.
    // !!! DANGER !!! Setting this flag to `false` makes your app
    // vulnerable to XSS attacks.
    sanitizeOnPaste: true,
);

// 2. another way to add global CSS is to call this async method:
await stylingOptions.importCssFromFile('path/to/style.css');

// ...

// Now create the editor passing the styling options
return HtmlEditor(
    controller: HtmlEditorController(stylingOptions: stylingOptions),
    onChanged: (p0) => (p0) {/* TODO */},
    initialValue: '' /* TODO */,
);
```

The code above should result in the following HTML being generated for each paragraph:

```html

<p style="text-indent:3.5em; text-align:justify;" class="my-custom-pgf"></p>

```

### Sizing and Constraints

By default, the widget occupies all available width and sizes its height based on the height of its content, but not less than the value of `minHeight` attribute of [HtmlEditor] widget.

```Dart
    // since explicit height is not provided - the editor will size itself
    // based on content, but will be not less than 250px
    return HtmlEditor(
      controller: controller,
      // ...
      minHeight: 250, // should be not less than 64px
      // ...
    );

    // and here you can listen to changes in height of the editor
    ValueListenableBuilder<double>(
        valueListenable: controller.totalHeight,
        builder: (BuildContext context, double value, Widget? child) {
        return Text('Height changed to $value\n'
            'Toolbar height is ${controller.toolbarHeight}\n'
            'Content height is ${controller.contentHeight}\n' );
        });
    
```

<br />
If explicit `height` is provided - the widget will size it's height precisely to the value of `height` attribute. In this case, if content height is greater than the widget height - the content becomes scrollable.

```Dart
    // here we've provided the height value, so the editor will always be
    // that height and the content will scroll if overflows the height.
    return HtmlEditor(
      height: 250,
    );
```

<br />
If `expandFullHeight` is set to `true` - the widget will take up all available height.

```Dart

    return HtmlEditor(
      expandFullHeight: true,
    );
```

____


### Toolbar Position

All toolbar-related options are contained within [ToolbarOptions] of [HtmlEditorController] class. Toolbar could be positionned:

 * __above__ or __below__ the editor container, by setting the `toolbarPosition` attribute;


#### Above editor:
![Toolbar above editor](./media/tb_above.png)


#### Below editor:
![Toolbar below editor](./media/tb_below.png)


 * __detached__ from the editor and located anywhere outside the [HtmlEditor]widget. This allows [ToolbarWidget] to be attached to several HtmlEditors. For this type of implementation please refer to the example within the package. 
 ![Toolbar floating](./media/tb_custom.png)

 * _scrollable_, _grid_ or _expandable_ by setting the `toolbarType` attribute


____


### Toolbar Contents and Custom Button Groups

Toolbar button groups could be enabled/disabled via `defaultToolbarButtons` attribute of [HtmlToolbarOptions] class within the controller. You can customize the toolbar by overriding the default value of this attribute.
<br /><br />
To add your own button group to the toolbar, you need to provide a list of [CustomButtonGroup] objects to the `customButtonGroups` attribute. Each button group will consist of a list of [CustomToolbarButton] objects, each with its own icon, tap callback and an `isSelected` flag to let the toolbar know if the icon button should be highlighted.


```Dart
HtmlEditor(
    controller: HtmlEditorController()
        ..toolbarOptions.customButtonGroups = [
        CustomButtonGroup(
            index: 0, // place first
            buttons: [
            CustomToolbarButton(
                icon: Icons.save_outlined,
                action: () => /* TODO: implement your save method */,
                isSelected: false)
        ])
        ],
    ),
```
=
![Custom button](./media/custom_toolbar_button.jpg)


____


### Voice to Text (Dictation)

Voice-to-text feature is powered by [speech_to_text](https://pub.dev/packages/speech_to_text) package and comes enabled by default with this package.
To disable voice-to-text feature - set the corresponding top-level `enableDictation` attribute within [HtmlEditor] constructor to `false`.

Overriding `controller.toolbarOptions.defaultToolbarButtons` value also overrides `enableDictation` flag (obviously), so you need to add `const VoiceToTextButtons()` in order to keep seeing the voice-to-text button.

____

## Special Considerations and Gotchas

1. Due to some framework issues on ***Web***, this plugin is only compatible with Flutter 3.3 and up. If you want to use this plugin with earlier versions of Flutter - make sure to downgrade pointer_interceptor dependency in your project to __0.9.0+1__.

2. Following needs to be done to make things work on each platform:

### Android

For speech recognition to work - place this to `android > app > src > main > AndroidManifest.xml`

```xml

<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.example">

    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.BLUETOOTH" />
    
   <application
    ...
```

### iOS
For speech recognition to work - add following permission to your `Info.plist` file:
```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>recognize speech</string>
<key>NSMicrophoneUsageDescription</key>
<string>Need microphone access for uploading videos</string>
```

### Web Platform

To get the toolbar to scroll horizontally on Web, you will need to make sure you override the default scroll behavior:

1. Add the following class override to your app:
    ```Dart
    class MyCustomScrollBehavior extends MaterialScrollBehavior {
    @override
    Set<PointerDeviceKind> get dragDevices => {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
        };
    }

    ```

2. Add the following attribute to the [MaterialApp] widget:

    ```Dart
    return MaterialApp(
        // ...
        scrollBehavior: MyCustomScrollBehavior(),
        // ...
    );

    ```

Done. Now you should be able to drag the toolbar left and right on web.


