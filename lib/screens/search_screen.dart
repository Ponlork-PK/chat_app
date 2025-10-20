import 'package:chat_app/screens/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ignore: must_be_immutable
class SearchScreen extends StatelessWidget {
  RxInt myId;
  final RxList<String> names;
  final RxList<String> images;
  SearchScreen({super.key, required this.myId, required this.names, required this.images});

  final RxString searchQuery = ''.obs;

  List<int> _filteredNames(){
    final query = searchQuery.value.trim().toLowerCase();
    if(query.isEmpty) return const <int>[].obs;
    final me = myId.value;
    final total = names.length;

    final indices = <int>[].obs;
    for( int i = 0; i<total; i++ ){
      if(i == me) continue;
      if(query.isEmpty || names[i].toLowerCase().contains(query)){
        indices.add(i);
      }
    }

    return indices;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: _buildAppBar,
        body: _buildBody,
      ),
    );
  }

  get _buildAppBar => AppBar(
    titleSpacing: 0,
    leading: IconButton(onPressed: (){Get.back();}, icon: Icon(Icons.arrow_back_ios, color: Colors.black,)),
    backgroundColor: Colors.white,
    title: SearchBar(
      padding: WidgetStatePropertyAll(EdgeInsets.zero),
      backgroundColor: WidgetStateProperty.all(
        Colors.transparent,
      ),
      elevation: WidgetStateProperty.all(0),
      hintText: 'search',
      hintStyle: WidgetStatePropertyAll(TextStyle(fontSize: 20)),
      onChanged: (value) {
        searchQuery.value = value;
      },
    ),
  );

  get _buildBody => Obx(() {
    final q = searchQuery.value.trim();
    if(q.isEmpty) {
      return Center(child: Text('tap to search', style: TextStyle(fontSize: 18),),);
    }

    final indice = _filteredNames();
    if(indice.isEmpty) {
      return Center(child: Text('no result', style: TextStyle(fontSize: 18)));
    }

    return Column(
      children: List.generate(
        indice.length,
        (pos) {
          final index = indice[pos];
          return Container(
            height: 65,
            margin: EdgeInsets.only(bottom: 5),
            child: InkWell(
              onTap: () {
                print(myId.value);
                Get.to(
                  ChatScreen(
                    name: names[index].obs, 
                    myImage: images[myId.value].obs,
                    peerImage: images[index].obs,
                    myId: myId,
                    peerId: index.obs,
                  )
                );
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 10.0,
                      right: 10,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.network(
                        width: 60,
                        height: 60,
                        images[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        names[index],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  });

}