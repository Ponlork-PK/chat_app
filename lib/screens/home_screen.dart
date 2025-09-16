import 'package:chat_app/screens/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ignore: must_be_immutable
class HomeScreen extends StatelessWidget {
  RxInt id;
  HomeScreen({super.key, required this.id});

  var names = <String>['Alex', 'Jonh', 'Long', 'You', 'Sanchez', 'Oddo'].obs;
  var images = <String>[
    'https://imgv3.fotor.com/images/blog-cover-image/10-profile-picture-ideas-to-make-you-stand-out.jpg',
    'https://images.pexels.com/photos/1704488/pexels-photo-1704488.jpeg?auto=compress&cs=tinysrgb&dpr=1&w=500',
    'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSHafp4PCblRXceHO8fYuQ7YAUZal2P1cp0HA&s',
    'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcScMFTFjYCu6HWnfspcstISJx39q5Ur1F936Q&s',
    'https://images.unsplash.com/photo-1529665253569-6d01c0eaf7b6?fm=jpg&q=60&w=3000&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8NHx8cHJvZmlsZXxlbnwwfHwwfHx8MA%3D%3D',
    'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQM9pd0t__V2hPYr2QPgbSDP26aZTnwLezZaw&s',
  ].obs;
  var messages = <String>[
    '2 new messages . 12:30 PM',
    '2 new messages . 12:30 PM',
    '2 new messages . 12:30 PM',
    '2 new messages . 12:30 PM',
    '2 new messages . 12:30 PM',
    '2 new messages . 12:30 PM',
    '2 new messages . 12:30 PM',
    '2 new messages . 12:30 PM',
    '2 new messages . 12:30 PM',
  ].obs;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          // backgroundColor: Colors.transparent,
          centerTitle: false,
          title: const Text('messenger'),
          actions: [
            InkWell(onTap: () {}, child: const Icon(Icons.note_add)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: InkWell(
                onTap: () {},
                child: CircleAvatar(
                  radius: 15,
                  child: Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Facebook_Logo_%282019%29.png/500px-Facebook_Logo_%282019%29.png',
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            children: [
              // Search
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 10, top: 10),
                child: TextFormField(
                  autocorrect: false,
                  decoration: const InputDecoration(
                    label: Text('Search', style: TextStyle(fontSize: 24)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                  ),
                ),
              ),

              // Story
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Obx(() {

                    final total = names.length;
                    final selected = id.value;
                    final indices = <int>[selected];
                    for(var i = 0; i < total; i++ ) {
                      if( i != selected ) indices.add(i);
                    }
                    return Row(
                      children: List.generate(indices.length, (pos) {
                        final index = indices[pos];
                        return Container(
                          margin: EdgeInsets.only(right: 10),
                          child: InkWell(
                            onTap: () {},
                            child: SizedBox(
                              child: Column(
                                children: [
                                  SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: index == indices[0]
                                        ? Stack(
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(45),
                                                  border: Border.all(color: Colors.green, width: 3,)
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.all(
                                                    Radius.circular(40),
                                                  ),
                                                  child: Image.network(
                                                    width: 80,
                                                    height: 80,
                                                    images[index],
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                left: 56,
                                                bottom: 0,
                                                child: InkWell(
                                                  child: const Icon(Icons.add),
                                                  onTap: () {},
                                                ),
                                              ),
                                            ],
                                          )
                                        : Stack(
                                            children: [
                                              ClipRRect(
                                                borderRadius: BorderRadius.all(
                                                  Radius.circular(40),
                                                ),
                                                child: Image.network(
                                                  width: 80,
                                                  height: 80,
                                                  images[index],
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                              Positioned(
                                                right: 5,
                                                bottom: 4,
                                                child: CircleAvatar(
                                                  radius: 8,
                                                  backgroundColor: Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(names[index]),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  })
                  
                ),
              ),

              // MessagesWidget
              Column(
                children: List.generate(
                  names.length,
                  (index) {
                    if(index == id.value) return const SizedBox.shrink();
                    return Container(
                      height: 85,
                      margin: EdgeInsets.only(bottom: 5),
                      child: InkWell(
                        onTap: () {
                          print(id.value);
                          Get.to(ChatScreen(name: names[index].obs, image: images[index].obs));
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
                                borderRadius: BorderRadius.circular(40),
                                child: Image.network(
                                  width: 80,
                                  height: 80,
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
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  messages[index],
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
