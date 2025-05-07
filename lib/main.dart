import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'stats.dart';
import 'database.dart' show DatabaseHelper;
import 'utils.dart' show getTrialStatus;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const Sortyfiy());
}

const String openAiApiKey = "***";

Future<Map<String, dynamic>?> fetchProductData(String barcode) async {
  final url =
      Uri.parse("https://world.openfoodfacts.org/api/v0/product/$barcode.json");

  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data.containsKey('product')) {
        return data['product'];
      }
    }
  } catch (e) {
    return null;
  }
  return null;
}

class Sortyfiy extends StatelessWidget {
  const Sortyfiy({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sortyfiy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: '♻️ Sortyfiy ♻️'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

enum ScanStatus { start, scanning, scanned, notFound, error }

class _MyHomePageState extends State<MyHomePage> {
  String _barcodeResult = "745175597500";
  String _productName = "Ritter Sport Schokolade Marzipan 100g (Ritter Sport)";
  List<Map<String, String>> _packagingDetails = [];
  ScanStatus _scanStatus = ScanStatus.start;

  bool _isProcessing = false;

  bool _isTrialExpired = false;

  double progress = 0.0;
  int scanGoal = 60;
  int scans = 0;
  int foundItems = 0;
  int recognizedPackaging = 0;
  int notRecognizedPackaging = 0;
  int recommendedDisposals = 0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
    checkTrialStatus();
  }

  void checkTrialStatus() async {
    final expired = await getTrialStatus();
    setState(() {
      _isTrialExpired = expired;
    });
  }

  Future<void> _loadStatistics() async {
    final stats = await DatabaseHelper.instance.getStatistics();
    setState(() {
      scans = stats['scans'] ?? 0;
      foundItems = stats['found_items'] ?? 0;
      recognizedPackaging = stats['recognized_packaging'] ?? 0;
      notRecognizedPackaging = stats['not_recognized_packaging'] ?? 0;
      recommendedDisposals = stats['recommended_disposals'] ?? 0;
      progress = (scans / scanGoal).clamp(0.0, 1.0);
    });
  }

  void openWhatsApp() async {
    final String phone = "491759580976"; // deine WhatsApp-Nummer
    final String whatsappMessage = "Hallo Sascha, ich habe die App getestet!";
    final url = Uri.parse(
        "https://wa.me/$phone?text=${Uri.encodeComponent(whatsappMessage)}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw "Could not launch WhatsApp";
    }
  }

  void sendEmail() async {
    final String email = "sascha.poenicke@googlemail.com";
    final String emailSubject = "Test Recycling-App";
    final String emailBody =
        "Hallo Sascha,\n\nder Test der App ist abgeschlossen.";

    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query:
          'subject=${Uri.encodeComponent(emailSubject)}&body=${Uri.encodeComponent(emailBody)}',
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      throw 'Could not launch email';
    }
  }

  void scanNew(BuildContext context) {
    /* setState(() {
      _scanStatus = ScanStatus.scanning;
    }); */
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: () => {Navigator.of(context).pop()},
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
              ),
            ),
            title: const Text("Barcode scannen"),
          ),
          body: Stack(children: [
            MobileScanner(
              onDetect: (barcodeCapture) {
                if (barcodeCapture.barcodes.isEmpty) return;
                if (_isProcessing) return;
                _isProcessing = true;
                final String? barcode = barcodeCapture.barcodes.first.rawValue;

                if (barcode != null) {
                  setState(() {
                    _scanStatus = ScanStatus.scanning;
                  });
                  // wait half a second to prevent multiple scans
                  Navigator.of(context).pop();

                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (!mounted) return;
                    _isProcessing = false;
                    processBarcode(barcode);
                  });
                }
              },
            ),
            Center(
              child: Container(
                width: 250,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> processBarcode(String barcode) async {
    DatabaseHelper.instance.incrementScan();
    setState(() {
      scans++;
      progress = (scans / scanGoal).clamp(0.0, 1.0);
    });
    final product = await fetchProductData(barcode);
    if (!mounted) return;

    if (product != null) {
      DatabaseHelper.instance.incrementFoundItems();
      setState(() {
        _barcodeResult = barcode;
        _productName = product['product_name'] ?? "Unbekanntes Produkt";
      });

      final packagingDetails = await extractPackagingDetails(product);
      if (!mounted) return;
      setState(() {
        _packagingDetails = packagingDetails;
        _scanStatus = ScanStatus.scanned;
      });
    } else {
      setState(() {
        _scanStatus = ScanStatus.notFound;
      });
    }
    _isProcessing = false;
  }

  Future<List<Map<String, String>>> extractPackagingDetails(
      Map<String, dynamic> product) async {
    List<Map<String, String>> packagingDetails = [];

    if (product.containsKey('packagings')) {
      for (var packaging in product['packagings']) {
        String shape = cleanLanguageTag(packaging['shape']);
        String recycling = cleanLanguageTag(packaging['recycling']);
        String material = cleanLanguageTag(packaging['material']);

        if (shape == "Unbekannt") {
          shape = "Verpackung";
        }

        final translatedData = await getRecyclingProposal(
            {"shape": shape, "material": material, "recycling": recycling});
        shape = translatedData["shape"] ?? shape;
        recycling = translatedData["recycling"] ?? recycling;

        packagingDetails.add({
          "shape": shape,
          "recycling": recycling,
        });
      }
    } else if (product.containsKey('packaging')) {
      String packaging = cleanLanguageTag(product['packaging']);

      final translatedData =
          await getRecyclingProposal({"packaging": packaging});
      packaging = translatedData["packaging"] ?? packaging;

      packagingDetails.add({
        "shape": packaging,
        "recycling": "Keine Recycling-Informationen verfügbar",
      });
    }
    if (packagingDetails.isEmpty) {
      DatabaseHelper.instance.incrementNotRecognizedPackaging();
      packagingDetails = [
        {"shape": "Keine Verpackungsdaten gefunden", "recycling": ""}
      ];
    } else {
      DatabaseHelper.instance.incrementRecognizedPackaging();
      DatabaseHelper.instance.incrementRecommendedDisposals();
    }
    return packagingDetails;
  }

  String cleanLanguageTag(String? text) {
    if (text == null) return "Unbekannt";
    return text.replaceAll(RegExp(r'^[a-z]{2,3}:'), '');
  }

  Future<Map<String, String>> getRecyclingProposal(
      Map<String, String> data) async {
    const String apiUrl = "https://api.openai.com/v1/chat/completions";

    final requestBody = {
      "model": "gpt-4o",
      "messages": [
        {
          "role": "system",
          "content":
              "Du bist ein Übersetzungsexperte und Recyclingexperte. Antworte nur mit JSON im Format {\"shape\": \"Übersetzung\", \"recycling\": \"Entsorgung\"} und nichts anderem."
        },
        {
          "role": "user",
          "content":
              "Übersetze diese Begriffe ins Deutsche und gib jeweils die korrekte Mülltonne zur Entsorgung an: ${jsonEncode(data)}"
        }
      ],
      "temperature": 0
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Authorization": "Bearer $openAiApiKey",
          "Content-Type": "application/json"
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));

        // Check if OpenAI's response is structured as expected
        if (responseData.containsKey("choices") &&
            responseData["choices"].isNotEmpty) {
          final String gptAnswer =
              responseData["choices"][0]["message"]["content"].trim();

          // Ensure response is a valid JSON object
          if (gptAnswer.startsWith("{") && gptAnswer.endsWith("}")) {
            final Map<String, dynamic> jsonResult = json.decode(gptAnswer);

            return {
              "shape": jsonResult["shape"] ?? data["shape"] ?? "Unbekannt",
              "recycling":
                  jsonResult["recycling"] ?? data["recycling"] ?? "Keine Info"
            };
          }
        }
      }
    } catch (e) {}
    return data; // Fallback, falls die API fehlschlägt
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
            spacing: 20,
            children: [
              Row(
                children: [
                  const Spacer(),
                  IconButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => const Stats(),
                        ),
                      );
                      _loadStatistics();
                      checkTrialStatus();
                      _scanStatus = ScanStatus.start;
                    },
                    icon: const Icon(Icons.info_outlined),
                    iconSize: 35,
                    color: Colors.white,
                  ),
                ],
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 0,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: .2),
                            offset: const Offset(0, 10),
                            blurRadius: 20,
                            spreadRadius: -15),
                      ],
                    ),
                    child: Image(
                      width: MediaQuery.of(context).size.width * 0.35,
                      image: AssetImage('assets/Sortyfy_Logo.png'),
                    ),
                  ),
                  Text(
                    "Sortlyfy",
                    style: TextStyle(
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: .2),
                          offset: const Offset(0, 10),
                          blurRadius: 20,
                        )
                      ],
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 15,
                          backgroundColor: Colors.white,
                          color: Colors.lightGreen,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        const SizedBox(height: 8),
                        if (scans >= scanGoal)
                          Text("🎉 Ziel erreicht 🎉",
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: Colors.white, fontSize: 18))
                        else
                          Text(
                            "$scans von $scanGoal Scans",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(40),
                  width: MediaQuery.of(context).size.width,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    color: Colors.white,
                  ),
                  child: Column(
                    children: [
                      switch (_scanStatus) {
                        ScanStatus.start => Expanded(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (scans < scanGoal && !_isTrialExpired)
                                    const Text(
                                        "Scanne einen Barcode ein, um zu erfahren, wie du das Produkt entsorgen kannst.",
                                        style: TextStyle(fontSize: 20),
                                        textAlign: TextAlign.center)
                                  else
                                    Column(
                                      children: [
                                        const Text(
                                            "Der Testzeitraum ist abgelaufen. \n Vielen Dank für deine Teilnahme! Bitte wende dich an Sascha, um Zugang zum Fragebogen zu erhalten.",
                                            style: TextStyle(fontSize: 18),
                                            textAlign: TextAlign.center),
                                        const SizedBox(height: 15),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          spacing: 10,
                                          children: [
                                            ElevatedButton(
                                              onPressed: () => {openWhatsApp()},
                                              style: TextButton.styleFrom(
                                                elevation: 2,
                                                shadowColor: Colors.black,
                                                foregroundColor: Colors.black,
                                                backgroundColor: Color.fromRGBO(
                                                    120, 219, 169, 1),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 20,
                                                        vertical: 10),
                                              ),
                                              child: Row(
                                                spacing: 5,
                                                children: [
                                                  Icon(Icons.message_outlined),
                                                  Text("WhatsApp")
                                                ],
                                              ),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => {sendEmail()},
                                              style: TextButton.styleFrom(
                                                elevation: 2,
                                                shadowColor: Colors.black,
                                                foregroundColor: Colors.black,
                                                backgroundColor: Color.fromRGBO(
                                                    120, 219, 169, 1),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 20,
                                                        vertical: 10),
                                              ),
                                              child: Row(
                                                spacing: 5,
                                                children: [
                                                  Icon(Icons.mail),
                                                  Text("Mail")
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ScanStatus.scanning => Expanded(
                            child: Center(
                                child: const CircularProgressIndicator())),
                        ScanStatus.notFound => Expanded(
                            child: Center(
                              child: const Text("❌ Produkt nicht gefunden",
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.red)),
                            ),
                          ),
                        ScanStatus.error => Expanded(
                            child: Center(
                              child: const Text("❌ Fehler beim Scannen",
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.red)),
                            ),
                          ),
                        ScanStatus.scanned => Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  if (scans >= scanGoal || _isTrialExpired)
                                    Column(
                                      children: [
                                        const Text(
                                            "Der Testzeitraum ist abgelaufen. \n Vielen Dank für deine Teilnahme! Bitte wende dich an Sascha, um Zugang zum Fragebogen zu erhalten.",
                                            style: TextStyle(fontSize: 15),
                                            textAlign: TextAlign.center),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          spacing: 10,
                                          children: [
                                            ElevatedButton(
                                              onPressed: () => {openWhatsApp()},
                                              style: TextButton.styleFrom(
                                                elevation: 2,
                                                shadowColor: Colors.black,
                                                foregroundColor: Colors.black,
                                                backgroundColor: Color.fromRGBO(
                                                    120, 219, 169, 1),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 20,
                                                        vertical: 10),
                                              ),
                                              child: Row(
                                                spacing: 5,
                                                children: [
                                                  Icon(Icons.mail),
                                                  Text("WhatsApp")
                                                ],
                                              ),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => {sendEmail()},
                                              style: TextButton.styleFrom(
                                                elevation: 2,
                                                shadowColor: Colors.black,
                                                foregroundColor: Colors.black,
                                                backgroundColor: Color.fromRGBO(
                                                    120, 219, 169, 1),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 20,
                                                        vertical: 10),
                                              ),
                                              child: Row(
                                                spacing: 5,
                                                children: [
                                                  Icon(Icons.mail),
                                                  Text("Mail")
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  const SizedBox(height: 12),
                                  Text("📌 Barcode: $_barcodeResult",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 18)),
                                  const SizedBox(height: 10),
                                  Text("📦 Produkt: $_productName",
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 20),
                                  ..._packagingDetails.map(
                                    (packaging) => Column(
                                      children: [
                                        if (packaging['recycling'] == '')
                                          Text(
                                              "Keine Verpackungsdaten gefunden",
                                              textAlign: TextAlign.center,
                                              style:
                                                  const TextStyle(fontSize: 16))
                                        else ...[
                                          Text(
                                              " Bestandteil: ${packaging['shape']}",
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  fontSize: 16)),
                                          Text(
                                              "♻️ Entsorgung: ${packaging['recycling']}",
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.green)),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      },
                      if (scans < scanGoal && !_isTrialExpired)
                        TextButton(
                          onPressed: () => scanNew(context),
                          style: TextButton.styleFrom(
                            elevation: 2,
                            shadowColor: Colors.black,
                            foregroundColor: Colors.black,
                            backgroundColor: Color.fromRGBO(120, 219, 169, 1),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 20),
                          ),
                          child: const Text('Scan',
                              style: TextStyle(fontSize: 20)),
                        ),
                    ],
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
