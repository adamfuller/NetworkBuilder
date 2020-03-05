part of app;

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
            icon: const Icon(Icons.looks_one),
            onPressed: vm.isTraining ? null : vm.stepPressed,
          ),
          IconButton(
            padding: const EdgeInsets.all(4),
            icon: const Icon(Icons.bug_report),
            onPressed: vm.testPressed,
          ),
          IconButton(
            padding: const EdgeInsets.all(4),
            icon: const Icon(Icons.refresh),
            onPressed: vm.resetNetwork,
          ),
          IconButton(
            padding: const EdgeInsets.all(4),
            icon: Icon(vm.toggleTrainingIcon),
            onPressed: vm.toggleTraining,
          ),
        ],
      ),
      body: vm.isLoading ? CircularProgressIndicator() : _getBody(),
    );
  }

  Widget _getRoundedCopyButton(String text, Function onPressed) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: RaisedButton.icon(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        icon: const Icon(Icons.content_copy),
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
          Text(
            "Average % Error: ${vm.network.averagePercentError.toStringAsFixed(8)}",
            textAlign: TextAlign.center,
          ),
          Text(
            "Times Run: ${vm.network.runCount}",
            textAlign: TextAlign.center,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _getTrainingFlexible(),
              _getNetworkMap(),
              Flexible(
                flex: 1,
                fit: FlexFit.tight,
                child: _getTestOutputCard(),
              )
            ],
          ),
        ]..removeWhere((w) => w == null),
      ),
    );
  }

  Widget _getTestOutputCard() {
    return Card(
      child: Container(
        height: MediaQuery.of(context).size.height / 2,
        width: MediaQuery.of(context).size.width / 4,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            child: Text("${vm.testOutputString}"),
          ),
        ),
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
            style: TextStyle(color: vm.isValidTrainingData ? Theme.of(context).textTheme.button.color : Colors.red),
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
            style: TextStyle(color: vm.isValidTrainingData ? Theme.of(context).textTheme.button.color : Colors.red),
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
        style: TextStyle(color: Theme.of(context).textTheme.subtitle2.color.withAlpha(125)),
      ),
      children: <Widget>[
        _getFunctionPicker(),
        Center(
          child: Text("Learning Factor: ${vm.network.learningRate.toStringAsFixed(8)}"),
        ),
        _getLearningRateSlider(),
        _getNeuronCounts(),
      ],
    );
  }

  Widget _getLearningRateSlider() {
    return Slider(
      value: vm.network.learningRate,
      label: (vm.network.learningRate).toStringAsFixed(5),
      divisions: 3000,
      min: 0.00001,
      max: 0.99999,
      onChanged: vm.learningRateChanged,
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
              onTap: () => vm.addLayerPressed(context, index),
              child: Card(
                child: Icon(Icons.add),
              ),
            );
          }
          return InkWell(
            key: ValueKey(index / 2),
            onLongPress: () => vm.removeLayerPressed(context, index),
            onTap: () => vm.resizeLayerPressed(context, index),
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
          value: vm.network.activationFunction,
          style: Theme.of(context).textTheme.button.apply(color: Colors.blue),
          onChanged: vm.activationFunctionChanged,
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
    return Flexible(
      flex: 2,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: NetworkMap(
          network: vm.network,
        ),
      ),
    );
  }
}
