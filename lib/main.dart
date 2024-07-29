import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:screenshot/screenshot.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(TextEditorApp());
}

class TextEditorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TextEditorModel(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: TextEditorScreen(),
      ),
    );
  }
}

class TextEditorScreen extends StatefulWidget {
  @override
  _TextEditorScreenState createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  final ScreenshotController screenshotController = ScreenshotController();

  Future<void> _saveScreenshot() async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw Exception('Unable to access storage directory');
      }

      // Capture screenshot
      final imagePath = await screenshotController.captureAndSave(directory.path, fileName: 'screenshot.jpg');

      if (imagePath != null) {
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Please select an output file:',
          fileName: 'screenshot.jpg',
          type: FileType.custom,
          allowedExtensions: ['jpg'],
        );

        if (result != null) {
          final File tempFile = File(imagePath);
          await tempFile.copy(result);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Screenshot saved successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No file selected.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing screenshot.')),
        );
      }
    } catch (e) {
      print("Error saving screenshot: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving screenshot: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Text Editor'),
        actions: [
          IconButton(
            icon: Icon(Icons.undo),
            onPressed: () {
              Provider.of<TextEditorModel>(context, listen: false).undo();
            },
          ),
          IconButton(
            icon: Icon(Icons.redo),
            onPressed: () {
              Provider.of<TextEditorModel>(context, listen: false).redo();
            },
          ),
          // IconButton(
          //   icon: Icon(Icons.save),
          //   onPressed: _saveScreenshot,
          // ),
        ],
      ),
      body: Screenshot(
        controller: screenshotController,
        child: Column(
          children: [
            TextEditorControls(),
            Expanded(
              child: Stack(
                children: Provider.of<TextEditorModel>(context)
                    .texts
                    .map((text) => DraggableText(text: text))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TextEditorControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var model = Provider.of<TextEditorModel>(context);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          DropdownButton<String>(
            value: model.fontFamily,
            items: ['Arial', 'Times New Roman', 'Courier New']
                .map((String font) {
              return DropdownMenuItem<String>(
                value: font,
                child: Text(font),
              );
            }).toList(),
            onChanged: (value) {
              model.setFontFamily(value);
            },
          ),
          SizedBox(width: 10),
          Container(
            width: 50,
            child: TextField(
              decoration: InputDecoration(labelText: 'Size'),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                model.setFontSize(double.tryParse(value) ?? 16);
              },
            ),
          ),
          SizedBox(width: 10),
          GestureDetector(
            onTap: () async {
              Color color = await showDialog(
                context: context,
                builder: (context) => ColorPickerDialog(
                  initialColor: model.color,
                ),
              );
              if (color != null) {
                model.setColor(color);
              }
            },
            child: Container(
              width: 30,
              height: 30,
              color: model.color,
            ),
          ),
          SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {
              _showAddTextDialog(context, model);
            },
            child: Text('Add Text'),
          ),
        ],
      ),
    );
  }

  void _showAddTextDialog(BuildContext context, TextEditorModel model) {
    TextEditingController _textController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter Text'),
          content: TextField(
            controller: _textController,
            decoration: InputDecoration(hintText: "Enter text here"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Add'),
              onPressed: () {
                model.addText(_textController.text);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class DraggableText extends StatefulWidget {
  final TextData text;

  DraggableText({required this.text});

  @override
  _DraggableTextState createState() => _DraggableTextState();
}

class _DraggableTextState extends State<DraggableText> {
  Offset offset = Offset.zero;

  @override
  void initState() {
    super.initState();
    offset = widget.text.position;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            offset += details.delta;
            Provider.of<TextEditorModel>(context, listen: false)
                .updateTextPosition(widget.text, offset);
          });
        },
        onTap: () {
          _showEditTextDialog(context, widget.text);
        },
        child: Container(
          child: Text(
            widget.text.content,
            style: TextStyle(
              fontSize: widget.text.fontSize,
              color: widget.text.color,
              fontFamily: widget.text.fontFamily,
            ),
          ),
        ),
      ),
    );
  }

  void _showEditTextDialog(BuildContext context, TextData text) {
    TextEditingController _textController = TextEditingController();
    _textController.text = text.content;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit Text'),
          content: TextField(
            controller: _textController,
            decoration: InputDecoration(hintText: "Enter new text"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () {
                Provider.of<TextEditorModel>(context, listen: false)
                    .updateTextContent(text, _textController.text);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class TextEditorModel extends ChangeNotifier {
  List<TextData> _texts = [];
  int _undoRedoIndex = -1;
  List<List<TextData>> _history = [];

  String _fontFamily = 'Arial';
  double _fontSize = 16;
  Color _color = Colors.black;

  String get fontFamily => _fontFamily;
  double get fontSize => _fontSize;
  Color get color => _color;
  List<TextData> get texts => _texts;

  void setFontFamily(String? fontFamily) {
    _fontFamily = fontFamily ?? 'Arial';
    notifyListeners();
  }

  void setFontSize(double fontSize) {
    _fontSize = fontSize;
    notifyListeners();
  }

  void setColor(Color color) {
    _color = color;
    notifyListeners();
  }

  void addText(String content) {
    _texts.add(TextData(
      content: content,
      fontSize: _fontSize,
      color: _color,
      fontFamily: _fontFamily,
      position: Offset(50, 50),
    ));
    _saveState();
    notifyListeners();
  }

  void updateTextContent(TextData text, String content) {
    text.content = content;
    _saveState();
    notifyListeners();
  }

  void updateTextPosition(TextData text, Offset position) {
    text.position = position;
    _saveState();
    notifyListeners();
  }

  void undo() {
    if (_undoRedoIndex > 0) {
      _undoRedoIndex--;
      _texts = _history[_undoRedoIndex].map((text) => text.copy()).toList();
      notifyListeners();
    }
  }

  void redo() {
    if (_undoRedoIndex < _history.length - 1) {
      _undoRedoIndex++;
      _texts = _history[_undoRedoIndex].map((text) => text.copy()).toList();
      notifyListeners();
    }
  }

  void _saveState() {
    _undoRedoIndex++;
    if (_undoRedoIndex < _history.length) {
      _history = _history.sublist(0, _undoRedoIndex);
    }
    _history.add(_texts.map((text) => text.copy()).toList());
  }
}

class TextData {
  String content;
  double fontSize;
  Color color;
  String fontFamily;
  Offset position;

  TextData({
    required this.content,
    required this.fontSize,
    required this.color,
    required this.fontFamily,
    required this.position,
  });

  TextData copy() {
    return TextData(
      content: content,
      fontSize: fontSize,
      color: color,
      fontFamily: fontFamily,
      position: position,
    );
  }
}

class ColorPickerDialog extends StatelessWidget {
  final Color initialColor;

  ColorPickerDialog({required this.initialColor});

  @override
  Widget build(BuildContext context) {
    Color selectedColor = initialColor;

    return AlertDialog(
      title: Text('Pick a color'),
      content: SingleChildScrollView(
        child: BlockPicker(
          pickerColor: initialColor,
          onColorChanged: (color) {
            selectedColor = color;
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: Text('Select'),
          onPressed: () {
            Navigator.of(context).pop(selectedColor);
          },
        ),
      ],
    );
  }
}
