import 'package:chat_app/screens/chat_screen.dart';
import 'package:chat_app/screens/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ignore: must_be_immutable
class HomeScreen extends StatefulWidget {
  RxInt id;
  HomeScreen({super.key, required this.id,});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

final _globalKey = GlobalKey<FormState>();

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
].obs;

final TextEditingController _nameController = TextEditingController();
final TextEditingController _imageController = TextEditingController();

class _HomeScreenState extends State<HomeScreen> {
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
    centerTitle: false,
    titleSpacing: 0,
    title: const Text('messenger'),
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 10.0),
        child: IconButton(
          icon: Icon(Icons.note_add),
          onPressed: (){
            Get.defaultDialog(
              title: 'Add New Chat',
              titleStyle: TextStyle(
                fontWeight: FontWeight.bold,
              ),
              content: Form(
                key: _globalKey,
                child: Column(
                  spacing: 8,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        label: Text('Name:'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))
                      ),
                      validator: (value) {
                        if( value == null || value.trim().isEmpty ){
                          return 'Please input name';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _imageController,
                      decoration: InputDecoration(
                        label: Text('Profile image link:'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))
                      ),
                      validator: (value) {
                        if( value == null || value.trim().isEmpty ){
                          return 'Please input image link';
                        }
                        return null;
                      },
                    )
                  ],
                ),
              ),
              textCancel: 'Cancel',
              textConfirm: 'Add',
              cancelTextColor: Colors.red,
              onCancel: () {
                _nameController.clear();
                _imageController.clear();
              },
              onConfirm: (){
                print('clicked');
                if(_globalKey.currentState!.validate()){
                  final name = _nameController.text.trim();
                  final image = _imageController.text.trim();
                  names.add(name);
                  images.add(image);
                  messages.add('2 new messages . 12:30 PM');
                  _nameController.clear();
                  _imageController.clear();
                  Get.back();
                }
              }
            );
          }, 
        ),
      ),
    ],
  );
  
  get _buildBody => SingleChildScrollView(
    scrollDirection: Axis.vertical,
    child: Column(
      children: [ _search, _story, _message ],
    ),
  );

  get _search => Padding(
    padding: const EdgeInsets.only(left: 10, right: 10, top: 10),
    child: TextFormField(
      readOnly: true,
      autocorrect: false,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[350],
        hint: Row(
          spacing: 6,
          children: [
            Icon(Icons.search, size: 22,),
            Text('Search', style: TextStyle(fontSize: 18)),
          ],
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.all(Radius.circular(26)),
        ),
      ),
      onTap: () {
        Get.to(SearchScreen(myId: widget.id, names: names, images: images));
      },
    ),
  );

  get _story => Padding(
    padding: const EdgeInsets.all(10.0),
    child: SingleChildScrollView(
      clipBehavior: Clip.none,
      scrollDirection: Axis.horizontal,
      child: Obx(() {

        final total = names.length;
        final selected = widget.id.value;
        final indices = <int>[selected];
        for(var i = 0; i < total; i++ ) {
          if( i != selected ) indices.add(i);
        }
        
        return Row(
          children: List.generate(indices.length, (pos) {
            final index = indices[pos];

            return Container(
              margin: EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () {
                  print('clicked');
                  if(index != selected){
                    Get.to(
                      ChatScreen(
                        name: names[index].obs,
                        myImage: images[selected].obs,
                        peerImage: images[index].obs,
                        myId: widget.id,
                        peerId: index.obs,
                      )
                    );
                  }
                  
                },
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
                                      border: Border.all(color: Colors.green, width: 4,)
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
                                    left: 52,
                                    bottom: 2,
                                    child: GestureDetector(
                                      onTap: () {print('clicked');},
                                      child: Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[400],
                                          borderRadius: BorderRadius.circular(13),
                                          border: BoxBorder.all(color: Colors.white, width: 2)
                                        ),
                                        child: const Icon(Icons.add, size: 22,),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ClipRRect(
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
  );

  get _message => Obx((){
    return Column(
      children: List.generate(
        names.length,
        (index) {
          if(index == widget.id.value) return const SizedBox.shrink();
          return Container(
            height: 85,
            margin: EdgeInsets.only(bottom: 5),
            child: InkWell(
              onTap: () {
                print(widget.id.value);
                Get.to(
                  ChatScreen(
                    name: names[index].obs, 
                    myImage: images[widget.id.value].obs,
                    peerImage: images[index].obs,
                    myId: widget.id,
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
    );
  });

}