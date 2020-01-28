library app;

import 'dart:async';

import 'package:custom_widget/custom_widget.dart';
import 'package:flutter/material.dart';
import 'network/network.dart';

part 'main_view_model.dart';

void main() => runApp(MainApp());

class MainApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MainView(),
      debugShowCheckedModeBanner: false, // no debug banner
    );
  }
}

class MainView extends StatefulWidget {
  MainView();

  _MainViewState createState() => new _MainViewState();
}

class _MainViewState extends State<MainView> {
  MainViewModel vm;

  @override
  void initState() {
    vm = new MainViewModel(() {
      if (mounted) {
        setState(() {});
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Network Builder"),
        actions: <Widget>[
          Padding(
            padding: EdgeInsets.all(4),
            child: RaisedButton(
              child: Text("Reset"),
              onPressed: vm.init,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(4),
            child: RaisedButton(
              child: Text("${vm.isTraining ? "Stop Training" : "Start Training"}"),
              onPressed: vm.toggleTraining,
            ),
          ),
        ],
      ),
      body: vm.isLoading ? CircularProgressIndicator() : _getBody(),
    );
  }

  Widget _getBody() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _getFunctionPicker(),
          _getLearningRateSlider(),
          _getNeuronCounts(),
          Center(
            child: Text("Average % Error: ${vm.network.averagePercentError}"),
          ),
          Center(
            child: Text("Learning Rate: ${Layer.learningRate}"),
          ),
          _getNetworkMap(),
        ],
      ),
    );
  }

  Widget _getLearningRateSlider() {
    return Slider(
      value: Layer.learningRate,
      min: 0.00001,
      max: 0.99999,
      onChanged: (d) {
        setState(() {
          Layer.learningRate = d;
        });
      },
    );
  }

  Widget _getNeuronCounts() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        vm.network.layers.length * 2,
        (index) {
          if (index % 2 == 0) {
            return InkWell(
              onTap: () async {
                String neuronCountString = await showInputDialog(
                  context,
                  "Add new layer?",
                  subtitle: "This will reset the current network.",
                  hintText: "How many neurons?",
                );
                if (neuronCountString == null) return;
                int neuronCount = int.parse(neuronCountString);
                int insertIndex = (index / 2).floor() + 1;
                List<int> counts = vm.network.hiddenLayerNeuronCount;
                counts.insert(insertIndex, neuronCount);
                setState(() {
                  vm.network = Network(
                    counts,
                    normalizationFunction: vm.network.layers[0].normalizationFunction,
                  );
                });
              },
              child: Card(
                child: Icon(Icons.add),
              ),
            );
          }
          return InkWell(
            key: ValueKey(index / 2),
            onLongPress: () async {
              bool shouldRemove = await showConfirmDialog(
                context,
                "Remove Layer",
                "Do you want to remove this layer?",
                confirmText: "Yes",
                denyText: "No",
              );
              if (shouldRemove) {
                vm.network.layers.removeAt((index / 2).floor());
                int removeIndex = (index / 2).floor() + 1;
                List<int> counts = vm.network.hiddenLayerNeuronCount;
                counts.removeAt(removeIndex);
                setState(() {
                  vm.network = Network(
                    counts,
                    normalizationFunction: vm.network.layers[0].normalizationFunction,
                  );
                });
              }
            },
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text("${vm.network.layers[(index / 2).floor()].neurons.length}"),
              ),
            ),
          );
        },
      ).take(vm.network.layers.length * 2 - 1).toList(),
    );
  }

  Widget _getFunctionPicker() {
    return DropdownButton<NormalizationFunction>(
      value: Network.normalizationFunction,
      icon: Icon(Icons.arrow_downward),
      iconSize: 24,
      elevation: 16,
      style: TextStyle(color: Colors.blue),
      underline: Container(
        height: 2,
        color: Colors.blueAccent,
      ),
      onChanged: (NormalizationFunction newValue) {
        setState(() {
          Network.normalizationFunction = newValue;
        });
      },
      items: NormalizationFunction.values.map<DropdownMenuItem<NormalizationFunction>>((NormalizationFunction value) {
        return DropdownMenuItem<NormalizationFunction>(
          value: value,
          child: Text("${value.toString().split("\.")[1]}"),
        );
      }).toList(),
    );
  }

  Widget _getNetworkMap() {
    return Center(
      child: CustomWidget(
        duration: Duration(seconds: 1),
        size: MediaQuery.of(context).size.width,
        onPaint: (c, s, d) {
          Paint redPaint = Paint();
          redPaint.color = Colors.red;
          Paint bluePaint = Paint();
          bluePaint.color = Colors.blue;
          Paint linePaint = Paint();
          linePaint.strokeWidth = 1.5;
          double spaceInLayer = s.height / (vm.network.maxLayerSize + 1);
          double spaceBetweenLayers = s.width / (vm.network.layers.length + 1);

          for (int i = -1; i < vm.network.layers.length; i++) {
            double top = 10;
            double left = spaceBetweenLayers * 1.5 + spaceBetweenLayers * i;
            double length = 0;
            int count = i == -1 ? vm.network.layers[0].neurons[0].weights.length : vm.network.layers[i].neurons.length;
            length = top + count * spaceInLayer;
            int nextCount = i < vm.network.layers.length - 1 ? vm.network.layers[i + 1].neurons.length : 0;
            double nextLength = top + nextCount * spaceInLayer;
            top += (s.height - length) / 2;
            // c.drawRect(Rect.fromLTWH(left, top, 20, length), redPaint);
            double diameter = 15;
            double cornerLeft = left + 2.5;

            for (int j = 0; j < count; j++) {
              double cornerTop = top + j * spaceInLayer + 5;
              c.drawArc(Rect.fromLTWH(cornerLeft, cornerTop, diameter, diameter), 0, 7, true, bluePaint);
              if (i < vm.network.layers.length - 1) {
                for (int x = 0; x < vm.network.layers[i + 1].neurons.length; x++) {
                  double top2 = 10 + (s.height - nextLength) / 2;
                  Offset circle1Center = Offset(cornerLeft + diameter / 2, cornerTop + diameter / 2);
                  double corner2Top = top2 + x * spaceInLayer + 5;
                  Offset circle2Center = Offset(cornerLeft + spaceBetweenLayers + diameter / 2, corner2Top + diameter / 2);
                  double weight = 0;
                  if (vm.network.layers.length > i) {
                    weight = vm.network.layers[i + 1].neurons[x].weights[j];
                  }
                  if (weight <= 1) weight *= 255;

                  linePaint.color = Color.fromARGB(255, (weight > 0 ? weight : 0).floor(), (weight < 0 ? weight : 0).floor(), 0);
                  c.drawLine(circle1Center, circle2Center, linePaint);
                }
              }
            }
          }
        },
      ),
    );
  }
}

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
