import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

// Import the quiz data
Future<List<List<dynamic>>> loadCsv() async {
  try {
    final rawData =
        await rootBundle.loadString('assets/shuffled_quiz_questions.csv');
    final List<List<dynamic>> listData = const CsvToListConverter(
      shouldParseNumbers: false,
      fieldDelimiter: ',',
      eol: '\n',
    ).convert(rawData);

    //print("Parsed CSV rows: ${listData.length}");
    return listData;
  } catch (e) {
    //print("CSV parse error: $e");
    return [];
  }
}

// Store CSV Data globally for easy access:
final csvData = StateProvider<List<List<dynamic>>>((ref) => []);
final quizQuestions = StateProvider<List<List<dynamic>>>((ref) => []);

// Store Quiz selection state :
final quizSelect = StateProvider<String>((ref) => '');

// Store user Answers
final userAnswers = StateProvider<dynamic>((ref) => []);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trivia App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/', //Page navigation
      routes: {
        '/': (context) => HomePage(),
        '/quizPage': (context) => QuizPage(),
        '/resultsPage': (context) => ResultsPage(),
      },
    );
  }
}

// HomePage
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(child: QuizSelect()),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 1:
              showDialog(
                  context: context,
                  builder: (context) =>
                      AlertDialog(title: Text('Please select a quiz topic')));
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/resultsPage',
                  arguments: []);
              break;
            default:
          }
        },
        items: [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
              activeIcon: Icon(Icons.home)),
          BottomNavigationBarItem(
              icon: Icon(Icons.quiz_outlined), label: 'Quiz'),
          BottomNavigationBarItem(
              icon: Icon(Icons.leaderboard_outlined), label: 'Results'),
        ],
      ),
    );
  }
}

class QuizSelect extends ConsumerWidget {
  const QuizSelect({super.key});

  //Obtain CSV data from loadCSV and store it in csvData
  Future<void> _loadAndStoreCsv(WidgetRef ref) async {
    final data = await loadCsv();
    for (var i = 1; i < data.length; i++) {
      // skip header
      switch (data[i][6]) {
        case 'A':
          data[i][6] = data[i][2];
          break;
        case 'B':
          data[i][6] = data[i][3];
          break;
        case 'C':
          data[i][6] = data[i][4];
          break;
        case 'D':
          data[i][6] = data[i][5];
          break;
        default:
      }
    }
    ref.read(csvData.notifier).state = data;

    // List of [categoryName, startIndex, endIndex]
    List<List<dynamic>> questionData = [];

    String prevCategory = data[1][0];
    int startIndex = 1;

    for (int i = 2; i < data.length; i++) {
      String currentCategory = data[i][0];

      if (currentCategory != prevCategory) {
        questionData.add([prevCategory, startIndex, i - 1]);
        prevCategory = currentCategory;
        startIndex = i;
      }
    }
    // Add the last category
    questionData.add([prevCategory, startIndex, data.length - 1]);

    ref.read(quizQuestions.notifier).state = questionData;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _loadAndStoreCsv(ref);
    final data = ref.watch(quizQuestions);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            SizedBox(height: screenHeight / 4),
            Text('Which quiz do you want to play?'),
            Container(
              width: screenWidth / 2,
              padding: const EdgeInsets.all(16),
              child: Card(
                color: Colors.purple.shade100,
                child: data.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: data.length,
                        itemBuilder: (context, index) {
                          final row = data[index];
                          return ListTile(
                            hoverColor: Colors.purple.shade300,
                            contentPadding: const EdgeInsets.all(4),
                            title: Center(child: Text(row[0])),
                            onTap: () {
                              Navigator.pushReplacementNamed(
                                  context, '/quizPage',
                                  arguments: data[index]);
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//Quiz Page
class QuizPage extends ConsumerWidget {
  const QuizPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(csvData);
    final quizSelect = ModalRoute.of(context)!.settings.arguments as List;
    final questions = [];
    for (var i = quizSelect[1]; i <= quizSelect[2]; i++) {
      questions.add(data[i]);
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Tap correct option to select'),
            InkWell(
                child: Text('Submit?'),
                onTap: () {
                  final csvDataVar = ref.read(csvData.notifier).state;
                  final userAnswersVar = ref.read(userAnswers.notifier).state;
                  submitButton(context, csvDataVar, userAnswersVar);
                })
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: data.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final row = questions[index];
                int questionIndex = index + 1;
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text('Q$questionIndex) ${row[1]}'), // Question
                    subtitle: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                InkWell(
                                    onTap: () {
                                      final ua = ref.read(userAnswers.notifier);
                                      ua.state = [
                                        ...ua.state.where((e) =>
                                            e[1] !=
                                            index), // remove existing answer for the question
                                        [
                                          row[0],
                                          row[1],
                                          row[2],
                                        ], // add new answer
                                      ];
                                    },
                                    child: Text(row[2])),
                                InkWell(
                                    onTap: () {
                                      final ua = ref.read(userAnswers.notifier);
                                      ua.state = [
                                        ...ua.state.where((e) =>
                                            e[1] !=
                                            index), // remove existing answer for the question
                                        [
                                          row[0],
                                          row[1],
                                          row[3],
                                        ], // add new answer
                                      ];
                                    },
                                    child: Text(row[3])),
                                InkWell(
                                    onTap: () {
                                      final ua = ref.read(userAnswers.notifier);
                                      ua.state = [
                                        ...ua.state.where((e) =>
                                            e[1] !=
                                            index), // remove existing answer for the question
                                        [
                                          row[0],
                                          row[1],
                                          row[4],
                                        ], // add new answer
                                      ];
                                    },
                                    child: Text(row[4])),
                                InkWell(
                                    onTap: () {
                                      final ua = ref.read(userAnswers.notifier);
                                      ua.state = [
                                        ...ua.state.where((e) =>
                                            e[1] !=
                                            index), // remove existing answer for the question
                                        [
                                          row[0],
                                          row[1],
                                          row[5],
                                        ], // add new answer
                                      ];
                                    },
                                    child: Text(row[5])),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 50,
                            child: Icon(Icons.check_box_outline_blank),
                          )
                        ]),
                  ),
                );
              },
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          switch (index) {
            case 0:
              showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                        title: Text('Do you really want to quit?'),
                        content: Row(
                          children: [
                            IconButton(
                                onPressed: () => Navigator.pushReplacementNamed(
                                    context, '/'),
                                icon: Icon(Icons.check)),
                            IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: Icon(Icons.close))
                          ],
                        ),
                      ));

              break;
            case 2:
              final csvDataVar = ref.read(csvData.notifier).state;
              final userAnswersVar = ref.read(userAnswers.notifier).state;
              ref.read(userAnswers.notifier).state =
                  []; // clearing memory to prevent clashes wth next rounds
              submitButton(context, csvDataVar, userAnswersVar);
              break;
            default:
          }
        },
        items: [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.quiz),
              label: 'Quiz',
              activeIcon: Icon(Icons.quiz)),
          BottomNavigationBarItem(
              icon: Icon(Icons.leaderboard_outlined), label: 'Results'),
        ],
      ),
    );
  }
}

void submitButton(BuildContext context, List<List<dynamic>> csvData,
    List<dynamic> userAnswers) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Do you want to submit your answers?'),
      actions: [
        TextButton(
          onPressed: () {
            final result = answers(csvData, userAnswers);

            Navigator.pushReplacementNamed(context, '/resultsPage',
                arguments: result);
          },
          child: Text('Yes'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('No'),
        ),
      ],
    ),
  );
}

// Check user answers for grading
List<dynamic> answers(csvData, userAnswers) {
  final result = [];
  String verification = '';
  String correctAnswer = '';
  for (var i = 0; i < userAnswers.length; i++) {
    for (var j = 1; j < csvData.length; j++) {
      //ignoring header
      if (userAnswers[i][1] == csvData[j][1]) {
        if (userAnswers[i][2] == csvData[j][6]) {
          verification = 'Correct ✅';
        } else {
          verification = 'Wrong ❌';
          correctAnswer = 'Correct Answer: ${csvData[j][6]}';
        }
        result.add([
          userAnswers[i][0],
          userAnswers[i][1],
          csvData[j][6],
          verification,
          correctAnswer,
        ]);
      }
    }
  }
  return result;
}

// Results Page
class ResultsPage extends ConsumerWidget {
  const ResultsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var result = ModalRoute.of(context)!.settings.arguments as List;

    // Handle empty result (from the homepage to result page)
    if (result.isNotEmpty) {
      int correctScore = 0;
      int totalScore = 0;
      final questionData = ref.read(quizQuestions.notifier).state;
      for (var i = 0; i < questionData.length; i++) {
        if (questionData[i][0] == result[0][0]) {
          totalScore = questionData[i][2] - questionData[i][1] + 1;
        }
      }
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;

      for (var i in result) {
        if (i[3] == 'Correct ✅') {
          correctScore++;
        }
      }

      return Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  'You Scored: $correctScore of $totalScore in ${result[0][0]}'),
              InkWell(
                  child: Text('Play again?'),
                  onTap: () {
                    ref.read(userAnswers.notifier).state =
                        []; // clear previous round answers
                    Navigator.pushReplacementNamed(context, '/');
                  })
            ],
          ),
          automaticallyImplyLeading: false,
        ),
        body: Center(
            child: SizedBox(
          width: screenWidth / 2,
          height: screenHeight / 2,
          child: ListView.builder(
            itemCount: result.length,
            itemBuilder: (context, index) {
              final row = result[index];
              return Card(
                  child: ListTile(
                title: Text('Q)${row[1]}  ${row[2]} -> ${row[3]}.'),
                subtitle: Text('${row[4]}'),
                contentPadding: EdgeInsets.all(4),
              ));
            },
          ),
        )),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 2,
          onTap: (index) {
            switch (index) {
              case 0:
                ref.read(userAnswers.notifier).state =
                    []; // clear previous round answers
                Navigator.pushReplacementNamed(context, '/');
                break;
              default:
            }
          },
          items: [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.quiz_outlined), label: 'Quiz'),
            BottomNavigationBarItem(
                icon: Icon(Icons.leaderboard_outlined),
                label: 'Results',
                activeIcon: Icon(Icons.leaderboard)),
          ],
        ),
      );
    } else {
      return Scaffold(
          appBar: AppBar(
            title: Text('No results yet to show'),
            leading: IconButton(onPressed:() => Navigator.pushReplacementNamed(context, '/'),icon: Icon(Icons.arrow_back),),
          ),
          body: Center(child: Text('Please play a game first.')));
    }
  }
}
