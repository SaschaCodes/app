import 'package:flutter/material.dart';
import 'database.dart' show DatabaseHelper;
import 'utils.dart' show getEndDate, getRemainingTime, resetInstallDate;

class Stats extends StatefulWidget {
  const Stats({super.key});

  @override
  State<Stats> createState() => _StatsState();
}

class _StatsState extends State<Stats> {
  int scans = 0;
  int foundItems = 0;
  int recognizedPackaging = 0;
  int notRecognizedPackaging = 0;
  int recommendedDisposals = 0;

  String endDate = '';
  String remainingTime = '';

  @override
  void initState() {
    super.initState();
    _loadStatistics();
    _loadTrialStatus();
  }

  Future<void> _loadStatistics() async {
    final stats = await DatabaseHelper.instance.getStatistics();
    setState(() {
      scans = stats['scans'] ?? 0;
      foundItems = stats['found_items'] ?? 0;
      recognizedPackaging = stats['recognized_packaging'] ?? 0;
      notRecognizedPackaging = stats['not_recognized_packaging'] ?? 0;
      recommendedDisposals = stats['recommended_disposals'] ?? 0;
    });
  }

  Future<void> _loadTrialStatus() async {
    final end = await getEndDate();
    final remaining = await getRemainingTime();

    setState(() {
      endDate = end;
      remainingTime = remaining;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.teal,
              Colors.green,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 50),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    iconSize: 30,
                    color: Colors.white,
                  ),
                  const Spacer(),
                ],
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Statistiken",
                      style: TextStyle(
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: .2),
                            offset: const Offset(0, 10),
                            blurRadius: 20,
                          )
                        ],
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(40),
                  width: MediaQuery.of(context).size.width,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    color: Colors.white,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Scans: $scans",
                          style: const TextStyle(fontSize: 20),
                        ),
                        Text(
                          "Gefundene Artikel: $foundItems",
                          style: const TextStyle(fontSize: 20),
                        ),
                        Text(
                          "Verpackung erkannt: $recognizedPackaging",
                          style: const TextStyle(fontSize: 20),
                        ),
                        Text(
                          "Empfohlene Entsorgungen: $recommendedDisposals",
                          style: const TextStyle(fontSize: 20),
                        ),
                        Text(
                          "Verpackung nicht erkannt: $notRecognizedPackaging",
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Testversion läuft bis: $endDate",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20),
                        ),
                        Text(
                          "Verbleibende Zeit: $remainingTime",
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onLongPress: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                String enteredPassword = '';
                                return AlertDialog(
                                  title: Text('Zurücksetzen bestätigen'),
                                  content: TextField(
                                    autofocus: true,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                      labelText: 'Passwort eingeben',
                                    ),
                                    onChanged: (value) {
                                      enteredPassword = value;
                                    },
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () async {
                                        if (enteredPassword == 'dual') {
                                          await resetInstallDate();

                                          await DatabaseHelper.instance
                                              .resetStatistics();
                                          if (mounted) {
                                            Navigator.of(context).pop();
                                            _loadStatistics();
                                            _loadTrialStatus();
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content:
                                                      Text("Zurückgesetzt ✅")),
                                            );
                                          }
                                        } else {
                                          Navigator.of(context).pop();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    "❌ Falsches Passwort")),
                                          );
                                        }
                                      },
                                      child: Text('Bestätigen'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: Text('Abbrechen'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          child: Container(
                            color: Colors.transparent,
                            height: 50,
                            width: 50,
                            // 🕵️ Unsichtbarer Bereich zum Antippen
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
