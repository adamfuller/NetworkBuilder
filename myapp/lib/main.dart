library app;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'components/network_map.dart';
import 'network/network.dart';
import "tools/dialogs.dart";

part 'main_view_model.dart';

void main() => runApp(MainApp());

class MainApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Set orientations to horizontal
    SystemChrome.setPreferredOrientations(
      [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    );
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

  _MainViewState createState() => _MainViewState();
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
        title: Row(children: [
          _getRoundedCopyButton(vm.copyJsonButtonText, vm.saveJsonPressed),
          _getRoundedCopyButton(vm.copyMatrixButtonText, vm.saveMatrixPressed),
        ]),
        actions: <Widget>[
          IconButton(
            padding: const EdgeInsets.all(4),
            icon: Icon(Icons.refresh),
            onPressed: vm.resetNetwork,
          ),
          IconButton(
            padding: const EdgeInsets.all(4),
            icon: Icon(vm.trainingTimerIcon),
            onPressed: vm.toggleTraining,
          ),
        ],
      ),
      body: vm.isLoading ? CircularProgressIndicator() : _getBody(),
    );
  }

  Widget _getRoundedCopyButton(String text, Function onPressed) {
    return Padding(
      padding: EdgeInsets.all(4),
      child: RaisedButton.icon(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        icon: Icon(Icons.content_copy),
        label: Text(text),
        onPressed: onPressed,
      ),
    );
  }

  Widget _getBody() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _getNetworkSettings(),
          vm.network?.layers[0]?.neurons[0].output != null
              ? Center(
                  child: Text("Average % Error: ${vm.network.averagePercentError.toStringAsFixed(8)}"),
                )
              : null,
          Text(
            "Times Run: ${vm.network.timesRun}",
            textAlign: TextAlign.center,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _getTrainingFlexible(),
              Flexible(
                flex: 2,
                child: _getNetworkMap(),
              ),
              Flexible(
                flex: 1,
                fit: FlexFit.tight,
                child: Card(
                  child: Container(
                    height: MediaQuery.of(context).size.shortestSide / 2,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: SingleChildScrollView(
                        child: Text("${vm.testOutputString}"),
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        ]..removeWhere((w) => w == null),
      ),
    );
  }

  Widget _getTrainingFlexible() {
    return Flexible(
      flex: 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Training Input " + vm.trainingDataValidityString,
            style: TextStyle(color: vm.isValidTrainingData ? Colors.black : Colors.red),
          ),
          Container(
            height: MediaQuery.of(context).size.shortestSide / 3,
            child: _getMultilineTextCard(
              vm.networkInputsController,
              vm.networkInputsChanged,
              "Input Data",
            ),
          ),
          Text(
            "Training Output " + vm.trainingDataValidityString,
            style: TextStyle(color: vm.isValidTrainingData ? Colors.black : Colors.red),
          ),
          Container(
            height: MediaQuery.of(context).size.shortestSide / 3,
            child: _getMultilineTextCard(
              vm.networkOutputsController,
              vm.networkOutputsChanged,
              "Output Data",
            ),
          ),
        ],
      ),
    );
  }

  Widget _getMultilineTextCard(
    TextEditingController controller,
    Function(String) onchanged,
    String hint,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: TextField(
          keyboardType: TextInputType.multiline,
          maxLines: null,
          decoration: InputDecoration.collapsed(hintText: hint),
          controller: controller,
          onChanged: onchanged,
          textInputAction: TextInputAction.newline,
        ),
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

                int insertIndex = (index / 2).floor();
                List<int> counts = vm.network.hiddenLayerNeuronCount;
                counts.insert(insertIndex, neuronCount);
                // Set sampleData count to weight of initial layer
                int sampleCount = vm.network.layers[0].neurons[0].weights.length;
                // Generate junk sample data
                List<double> sample = List.filled(sampleCount, 0.5);
                // Insert the layer
                vm.network.layers.insert(insertIndex, Layer(0, neuronCount));
                // Feed it through and update
                setState(() {
                  vm.network.forwardPropagation(sample);
                  vm.network.timesRun = 0;
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
                vm.network.forwardPropagation(sample);
                vm.network.timesRun = 0;
                setState(() {});
              }
            },
            onTap: () async {
              String nextSizeString = await showInputDialog(
                context,
                "Update layer size?",
                keyboardType: TextInputType.number,
                subtitle: "How many neurons should be in this layer?",
              );
              if (nextSizeString == null || nextSizeString.isEmpty) return;
              int newSize = int.tryParse(nextSizeString);
              if (newSize == null) return;
              int updateIndex = (index / 2).floor();
              vm.network.layers[updateIndex].resize(newSize);
              List<double> sample = List.filled(newSize, 0.1);
              vm.network.layers[updateIndex + 1].forwardPropagation(sample);
              vm.network.timesRun = 0;
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
        const Padding(
          padding: const EdgeInsets.only(right: 8),
          child: const Text("Activation Function:"),
        ),
        DropdownButton<ActivationFunction>(
          value: Network.activationFunction,
          style: const TextStyle(color: Colors.blue),
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
      child: NetworkMap(
        network: vm.network,
      ),
    );
  }
}
