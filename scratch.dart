import 'dart:convert';

void main() {
  final jsonStr = '''
  {
      "status": true,
      "data": [
          {
              "contest": {
                  "id": 2,
                  "name": "contest one",
                  "tagline": "complete contest and win prices"
              },
              "is_enrolled": true,
              "participant": {
                  "id": 2
              }
          }
      ]
  }
  ''';
  
  final responseData = jsonDecode(jsonStr);
  final rawList = responseData is List ? responseData as List : (responseData['data'] as List? ?? <dynamic>[]);
  print("rawList length: \${rawList.length}");
  print("rawList type: \${rawList.runtimeType}");
  
  try {
    for (var e in rawList) {
       final map = e as Map<String, dynamic>;
       print(map);
    }
  } catch (e) {
    print("Error: \$e");
  }
}
