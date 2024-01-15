import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:registrar/providers.dart';

class BulletinPage extends StatefulWidget {
  const BulletinPage({Key? key}) : super(key: key);

  @override
  State<BulletinPage> createState() => _BulletinPageState();
}

class _BulletinPageState extends State<BulletinPage> {
  int _counter = 0;

  List<TextEditingController> controllers = [];

  List<String?> errors = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 3; i++) {
      controllers.add(TextEditingController());
      errors.add(null);
    }
  }

  void _addTextField() {
    setState(() {
      controllers.add(TextEditingController());
      errors.add(null);
    });
  }

  void _removeTextField() {
    setState(() {
      if (controllers.length > 3) {
        controllers.removeLast();
        errors.removeLast();
      }
    });
  }

  void validateFields(VoterProvider provider) {
    Map<int, String> bulletin = {};
    bool allFieldsValid = true;
    for (int i = 0; i < controllers.length; i++) {
      final text = controllers[i].value.text;
      if (text.isEmpty) {
        errors[i] = 'Это поле не может быть пустым';
        allFieldsValid = false;
      } else {
        errors[i] = null;
      }
    }

    if (allFieldsValid) {
      for (int i = 0; i < controllers.length; i++) {
        bulletin[i] = controllers[i].value.text;
      }
      provider.setBulletin(bulletin);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final voterProvider = Provider.of<VoterProvider>(context);
    final voters = voterProvider.voters;
    final Map<int, String> bulletin = voterProvider.bulletin;
    Widget viewForm(BuildContext context) {
      List<Widget> textFields = bulletin.entries.map((entry) {
        int index = entry.key;
        String value = entry.value;
        return TextFormField(
          initialValue: value,
          readOnly: true,
          decoration: InputDecoration(
            labelText: index == 0 ? 'Тема голосования' : 'Кандидат $index',
          ),
        );
      }).toList();

      Widget formFields = Column(children: textFields);

      return Column(
        children: <Widget>[
          const SizedBox(height: 10),
          const Text(
            'Утверждённый бюллетень',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: <Widget>[
                    ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [formFields],
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    Widget createForm(BuildContext context) {
      List<Widget> textFields = List.generate(
        controllers.length,
        (index) => TextFormField(
          controller: controllers[index],
          decoration: InputDecoration(
            labelText: index == 0 ? 'Тема голосования' : 'Кандидат $index',
            errorText: errors[index],
          ),
          validator: (value) {
            if (value!.isEmpty) {
              return 'Поле не может быть пустым!';
            }
            return null;
          },
        ),
      );
      Widget formFields;
      if (controllers.length < 3) {
        formFields = Column(children: [
          ...textFields,
          const SizedBox(height: 10),
          const Text(
            'Должно быть как минимум два кандидата',
            style: TextStyle(color: Colors.red),
          ),
        ]);
      } else {
        formFields = Column(children: textFields);
      }

      return Column(children: <Widget>[
        const SizedBox(height: 10),
        const Text('Оформление бюллетеня',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: <Widget>[
                  ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [formFields],
                  )
                ],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: ButtonBar(
            alignment: MainAxisAlignment.center,
            children: <Widget>[
              ElevatedButton(
                onPressed: () {
                  if (controllers.length < 21) {
                    _addTextField();
                  }
                },
                child: const Icon(Icons.add),
              ),
              ElevatedButton(
                onPressed: () {
                  _removeTextField();
                },
                child: const Icon(Icons.remove),
              ),
              ElevatedButton(
                onPressed: () {
                  validateFields(voterProvider);
                },
                child: const Text('Утвердить'),
              ),
            ],
          ),
        ),
      ]);
    }

    return bulletin.isEmpty ? createForm(context) : viewForm(context);
  }
}
