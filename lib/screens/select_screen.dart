import 'package:chat_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ignore: must_be_immutable
class SelectScreen extends StatelessWidget {
  SelectScreen({super.key});

  var names = <String>[
    'Alex',
    'Jonh',
    'Long',
    'You',
    'Sanchez', 'Oddo',
  ].obs;
  var images = <String>[
    'https://imgv3.fotor.com/images/blog-cover-image/10-profile-picture-ideas-to-make-you-stand-out.jpg',
    'https://images.pexels.com/photos/1704488/pexels-photo-1704488.jpeg?auto=compress&cs=tinysrgb&dpr=1&w=500',
    'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSHafp4PCblRXceHO8fYuQ7YAUZal2P1cp0HA&s',
    'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcScMFTFjYCu6HWnfspcstISJx39q5Ur1F936Q&s',
    'https://images.unsplash.com/photo-1529665253569-6d01c0eaf7b6?fm=jpg&q=60&w=3000&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxzZWFyY2h8NHx8cHJvZmlsZXxlbnwwfHwwfHx8MA%3D%3D',
    'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQM9pd0t__V2hPYr2QPgbSDP26aZTnwLezZaw&s',
  ].obs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat App')),
      body: SingleChildScrollView(
        child: Column(
          children: List.generate(names.length, (index) {
            return InkWell(
              onTap: () {
                print(index);
                Get.to(HomeScreen(id: index.obs));
              },
              child: Container(
                width: double.infinity,
                height: 80,
                margin: EdgeInsets.only(bottom: 5),
                decoration: BoxDecoration(color: Colors.amber),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 5,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        child: Row(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              margin: EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(35),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(35),
                                child: Image.network(
                                  width: 70,
                                  height: 70,
                                  images[index],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
              
                            Text(
                              names[index],
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
