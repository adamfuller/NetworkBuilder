import 'package:flutter/material.dart';

Future<bool> showConfirmDialog(
  BuildContext context,
  String title,
  String subtitle, {
  String confirmText = "Ok",
  String denyText = "Cancel",
}) async {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
        title: Text(title),
        content: Text(subtitle),
        actions: <Widget>[
          FlatButton(
            child: Text(denyText),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FlatButton(
            child: Text(confirmText),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      );
    },
  );
}

Future<String> showInputDialog(
  BuildContext context,
  String title, {
  String subtitle,
  TextInputType keyboardType,
  String hintText,
  int maxLines,
  bool offerRandomCode = false,
  int codeLength = 10,
}) async {
  TextEditingController _inputController = TextEditingController();
  return showDialog<String>(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        title: Text(title),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              subtitle != null ? Text(subtitle ?? "") : null,
              TextField(
                autofocus: true,
                keyboardType: keyboardType ?? TextInputType.text,
                controller: _inputController,
                maxLines: maxLines,
                decoration: InputDecoration(
                  hintText: hintText,
                ),
              ),
            ]..removeWhere((_) => _ == null),
          ),
        ),
        actions: <Widget>[
          FlatButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          FlatButton(
            child: const Text("Ok"),
            onPressed: () => Navigator.of(context).pop(_inputController.text),
          ),
        ]..removeWhere((_) => _ == null),
      );
    },
  );
}

class ScrollingTextField extends StatelessWidget {
  final void Function(String) onChanged;
  final void Function(String) onSubmitted;
  final TextEditingController controller;
  final TextInputAction textInputAction;
  final String hintText;
  final FocusNode focusNode;

  ScrollingTextField({
    this.controller,
    this.onChanged,
    this.textInputAction,
    this.onSubmitted,
    this.hintText,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => this.focusNode?.requestFocus(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12.0, 0, 5.0, 0),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: 10.0,
            maxHeight: MediaQuery.of(context).size.longestSide / 5,
          ),
          child: Scrollbar(
            child: ScrollConfiguration(
              behavior: NoOverscrollIndicatorBehavior(),
              child: SingleChildScrollView(
                child: TextField(
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  textInputAction: textInputAction,
                  focusNode: this.focusNode,
                  controller: this.controller,
                  onSubmitted: this.onSubmitted,
                  onChanged: this.onChanged,
                  decoration: InputDecoration.collapsed(hintText: this.hintText),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NoOverscrollIndicatorBehavior extends ScrollBehavior {
  @override
  Widget buildViewportChrome(BuildContext context, Widget child, AxisDirection axisDirection) {
    return child;
  }
}
