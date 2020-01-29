library app;

import 'dart:async';

import 'package:custom_widget/custom_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'network/network.dart';
import "tools/dialogs.dart";

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
        title: Padding(
          padding: EdgeInsets.all(4),
          child: RaisedButton(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text("${vm.copyJsonButtonText}"),
            onPressed: vm.savePressed,
          ),
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.all(4),
            child: RaisedButton(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text("Reset"),
              onPressed: vm.resetNetwork,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(4),
            child: RaisedButton(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
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
          _getNetworkSettings(),
          _getTrainingDataInputs(),
          _getTestOutputs(),
          vm.network?.layers[0]?.neurons[0].output != null
              ? Center(
                  child: Text("Average % Error: ${vm.network.averagePercentError.toStringAsFixed(8)}"),
                )
              : null,
          _getNetworkMap(),
        ]..removeWhere((w) => w == null),
      ),
    );
  }

  Widget _getNetworkSettings() {
    return ExpansionTile(
      leading: Icon(Icons.settings),
      title: Text("Network Settings"),
      subtitle: Text(
        "Activation Function, Learning Factor, Neurons/Layer",
        style: TextStyle(color: Theme.of(context).textTheme.subtitle.color.withAlpha(125)),
      ),
      // leading: Text("Settings"),
      // trailing: Icon(Icons.arrow_downward),
      children: <Widget>[
        _getFunctionPicker(),
        Center(
          child: Text("Learning Factor: ${Network.learningFactor.toStringAsFixed(8)}"),
        ),
        _getLearningRateSlider(),
        _getNeuronCounts(),
      ],
    );
  }

  Widget _getTrainingDataInputs() {
    return ExpansionTile(
      leading: Icon(Icons.edit),
      title: Text("Edit Training Data"),
      subtitle: (vm.inputsFromText.length == vm.outputsFromText.length)
          ? null
          : Text(
              "Input and Output length don't match!",
              style: TextStyle(color: Colors.red),
            ),
      trailing: RaisedButton.icon(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        icon: Icon(Icons.done),
        label: Text("Update"),
        onPressed: vm.updateTrainingData,
      ),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
          child: ExpansionTile(
            title: Text("Input Training Set (${vm.inputsFromText.length})"),
            subtitle: Text(
              "Comma separated, newline indicates different inputs",
              style: TextStyle(color: Theme.of(context).textTheme.subtitle.color.withAlpha(125)),
            ),
            children: <Widget>[
              TextField(
                keyboardType: TextInputType.multiline,
                maxLines: null,
                decoration: InputDecoration.collapsed(hintText: "Input Data"),
                controller: vm.networkInputsController,
                onChanged: vm.networkInputsChanged,
                textInputAction: TextInputAction.newline,
                onEditingComplete: (){
                  print("F");
                },
                onSubmitted: (s){
                  print(s);
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
          child: ExpansionTile(
            title: Text("Expected Outputs (${vm.outputsFromText.length})"),
            subtitle: Text(
              "Comma separated, newline indicates different outputs",
              style: TextStyle(color: Theme.of(context).textTheme.subtitle.color.withAlpha(125)),
            ),
            children: <Widget>[
              TextField(
                keyboardType: TextInputType.multiline,
                maxLines: null,
                decoration: InputDecoration.collapsed(hintText: "Output Data"),
                controller: vm.networkOutputsController,
                onChanged: vm.networkOutputsChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _getTestOutputs() {
    return ExpansionTile(
      leading: Icon(Icons.view_stream),
      title: Text("Outputs"),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RaisedButton.icon(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            icon: Icon(Icons.content_copy),
            label: Text("${vm.copyButtonText}"),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: vm.testOutputString));
              setState(() {
                vm.copyButtonText = "Copied";
              });
              Timer(Duration(seconds: 1), () {
                setState(() {
                  vm.copyButtonText = "Copy";
                });
              });
            },
          ),
          Padding(
            padding: EdgeInsets.all(2),
          ),
          RaisedButton.icon(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            icon: Icon(Icons.done),
            label: Text("Test"),
            onPressed: vm.testPressed,
          ),
        ],
      ),
      children: <Widget>[
        Text("${vm.testOutputString}"),
      ],
    );
  }

  Widget _getLearningRateSlider() {
    return Slider(
      value: Network.learningFactor,
      label: (Network.learningFactor).toStringAsFixed(5),
      divisions: 3000,
      min: 0.00001,
      max: 0.99999,
      onChanged: (d) {
        setState(() {
          Network.learningFactor = d;
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
                  keyboardType: TextInputType.number,
                );
                if (neuronCountString == null) return;
                int neuronCount = int.tryParse(neuronCountString);
                if (neuronCount == null) return;

                int insertIndex = (index / 2).floor() + 1;
                List<int> counts = vm.network.hiddenLayerNeuronCount;
                counts.insert(insertIndex, neuronCount);
                setState(() {
                  vm.network = Network(
                    counts,
                    activationFunction: Network.activationFunction,
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
                int removeIndex = (index / 2).floor();
                // Set sampleData count to weight of initial layer
                int sampleCount = vm.network.layers[0].neurons[0].weights.length;
                // Generate junk sample data
                List<double> sample = List.filled(sampleCount, 0.5);
                // Remove the layer
                vm.network.layers.removeAt(removeIndex);
                // Pass the sample data to correct weights
                vm.network.feedForward(sample);
                setState(() {});
              }
            },
            onTap: () async {
              String nextSizeString = await showInputDialog(
                context,
                "Update layer size?",
                subtitle: "How many neurons should be in this layer?",
              );
              if (nextSizeString == null || nextSizeString.isEmpty) return;
              int newSize = int.tryParse(nextSizeString);
              if (newSize == null) return;
              int updateIndex = (index / 2).floor();
              vm.network.layers[updateIndex].resize(newSize);
              List<double> sample = List.filled(newSize, 0.1);
              vm.network.layers[updateIndex + 1].forwardPropagation(sample);
              setState(() {});
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text("Activation Function:"),
        ),
        DropdownButton<ActivationFunction>(
          value: Network.activationFunction,
          icon: Icon(Icons.arrow_downward),
          iconSize: 24,
          elevation: 16,
          style: TextStyle(color: Colors.blue),
          underline: Container(
            height: 2,
            color: Colors.blueAccent,
          ),
          onChanged: (ActivationFunction newValue) {
            setState(() {
              Network.activationFunction = newValue;
            });
          },
          items: ActivationFunction.values.map<DropdownMenuItem<ActivationFunction>>(
            (ActivationFunction value) {
              return DropdownMenuItem<ActivationFunction>(
                value: value,
                child: Text("${value.toString().split("\.")[1]}"),
              );
            },
          ).toList(),
        ),
      ],
    );
  }

  Widget _getNetworkMap() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomWidget(
        size: MediaQuery.of(context).size.shortestSide,
        onPaint: (c, s, d) {
          Paint linePaint = Paint();
          linePaint.strokeWidth = 1.5;

          Paint neuronPaint = Paint();
          neuronPaint.color = Color.fromARGB(235, 0x21, 0x96, 0xF3);

          // double spaceInLayer = s.height / (vm.network.maxLayerSize + 1);
          double spaceBetweenLayers = s.width / (vm.network.layers.length + 1);
          double spaceAround = 20;
          double diameter = 10;
          List<List<Offset>> positions = List<List<Offset>>();
          List<Rect> nodePositions = List<Rect>();

          for (int i = 0; i < vm.network.layers.length + 1; i++) {
            positions.add(List<Offset>());
            List<Layer> sub = vm.network.layers.take(i).toList();
            Layer layer = (sub.length > 0 && i < vm.network.layers.length) ? sub.last : null;
            int nodeCount = layer != null ? layer.neurons.length : vm.network.layers[0].neurons[0].weights.length;
            if (i == vm.network.layers.length) {
              nodeCount = vm.network.layers.last.neurons.length;
            }
            double spaceBetweenNodes = (s.height - 2 * spaceAround) / nodeCount;
            double layerXPosition = spaceBetweenLayers / 2 + i * spaceBetweenLayers;
            // Draw the nodes
            for (int j = 0; j < nodeCount; j++) {
              double nodeYPosition = spaceBetweenNodes / 2 + spaceBetweenNodes * j + spaceAround;
              Rect nodeRect = Rect.fromLTWH(layerXPosition, nodeYPosition, diameter, diameter);
              nodePositions.add(nodeRect);
              // c.drawArc(nodeRect, 0, 6.29, true, neuronPaint);
              // Add points
              positions[i].add(Offset(layerXPosition + diameter / 2, nodeYPosition + diameter / 2));
            }
          }

          for (int i = 1; i < positions.length; i++) {
            // Draw from all in i to i-1
            // i-i is the index in the layers
            // j is the index of the weight
            for (int j = 0; j < positions[i].length; j++) {
              // position of point on right
              // index of the neuron
              for (int x = 0; x < positions[i - 1].length; x++) {
                // position of point to the left
                // also index of the weight
                double weight = vm.network.layers[i - 1].neurons[j].weights[x];
                if (weight <= 1) weight *= 255;
                linePaint.color = Color.fromARGB(255, (weight > 0 ? weight : 0).floor(), (weight < 0 ? weight : 0).floor(), 0);
                c.drawLine(positions[i][j], positions[i - 1][x], linePaint);
              }
            }
          }

          for (Rect r in nodePositions) {
            c.drawArc(r, 0, 6.29, true, neuronPaint);
          }
        },
      ),
    );
  }
}
