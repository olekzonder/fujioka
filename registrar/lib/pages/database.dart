import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:registrar/providers.dart';

class DatabasePage extends StatefulWidget {
  const DatabasePage({Key? key}) : super(key: key);
  @override
  _DatabasePageState createState() => _DatabasePageState();
}

class _DatabasePageState extends State<DatabasePage> {
  void resetDB(BuildContext context, voterProvider) async {
    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            content: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('Сброс базы данных ',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  SizedBox(height: 10),
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Пожалуйста, подождите')
                ],
              );
            }),
          );
        });
    await voterProvider.resetDatabase();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final voterProvider = Provider.of<VoterProvider>(context);
    final voters = voterProvider.voters;
    Widget getVoterList() {
      return Column(children: [
        const SizedBox(height: 10),
        const Text(
          "База данных избирателей",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        voters.isEmpty
            ? const Expanded(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Text("Ни один избиратель не зарегистрирован")]))
            : Expanded(
                child: SingleChildScrollView(
                    child: Column(children: [
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: voters.length,
                  itemBuilder: (BuildContext context, int index) {
                    int voterIndex = voters.keys.elementAt(index);
                    List<String> voterInfo = voters.values.elementAt(index);
                    String fullName = voterInfo[0];
                    String textFieldValue = voterInfo[1];
                    return ListTile(
                      title: Text(fullName),
                      subtitle: TextFormField(
                          initialValue: textFieldValue,
                          readOnly: true,
                          decoration: const InputDecoration(
                              labelText: 'Открытый ключ избирателя y')),
                      trailing: voterProvider.voteStarted
                          ? null
                          : ElevatedButton(
                              onPressed: () {
                                voterProvider.deleteUser(voterIndex);
                              },
                              child: const Icon(Icons.delete),
                            ),
                    );
                  },
                ),
              ]))),
        voterProvider.voteStarted
            ? const Text('Во время голосования нельзя изменять значения')
            : ElevatedButton(
                onPressed: () {
                  resetDB(context, voterProvider);
                },
                child: const Text('Сбросить БД')),
        //сюда CheckBox
        const SizedBox(height: 10),
      ]);
    }

    return getVoterList();
  }
}
