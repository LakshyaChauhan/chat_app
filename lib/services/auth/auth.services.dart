import 'dart:io';

import 'package:chat_app/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class AuthServices {
  // instances of firebasauth and firestore
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;
  final FirebaseStorage _firebaseStorage = FirebaseStorage.instance;

  Future<void> signInWithEmailAndPassword(
      String email, String password, BuildContext context) async {
    bool emailAlreadyExist = await checkEmailExsist(email);
    if (emailAlreadyExist) {
      try {
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
            email: email, password: password);
        await _firebaseFirestore
            .collection('Users')
            .doc(userCredential.user!.uid)
            .update({'isOnline': true});
      } on FirebaseAuthException catch (e) {
        print(
            'The error is in the authentication login section of the program');
        throw Exception(e.code);
      }
    } else {
      throw Exception('Invalid email or password');
    }
  }

  // sign up or register
  Future<UserCredential> signUp(UserModel userModel, String password) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
              email: userModel.email, password: password);
      String? url;
      // store the profile pic on the firebase storage
      if (userModel.profilePic != '') {
        url = await uploadFile(userModel.profilePic!, userCredential.user!.uid);
      }
      UserModel newModel = UserModel(
          userName: userModel.userName,
          name: userModel.name,
          email: userModel.email,
          isOnline: userModel.isOnline,
          profilePic: url != null ? url : userModel.profilePic,
          uid: userCredential.user!.uid);
      await _firebaseFirestore
          .collection('Users')
          .doc(userCredential.user!.uid)
          .set(newModel.toMap());
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('Error in signup method in AuthServices.dart file');
      throw Exception(e.code);
    }
  }

  // sign out or log out
  Future<void> signOut() async {
    await _auth.signOut();
    await _firebaseFirestore
        .collection('Users')
        .doc()
        .update({'isOnline': false});
  }

  Future<String> uploadFile(String filePath, uid) async {
    final fileName = filePath.split('/').last; // Get filename from path
    final reference = _firebaseStorage
        .ref()
        .child('$uid/$fileName'); // Replace with your folder name

    try {
      final task = reference.putFile(File(filePath));
      final snapshot = await task.whenComplete(() => null);
      final url = await snapshot.ref.getDownloadURL();
      return url;
    } on FirebaseException catch (e) {
      // Handle errors
      print(e.message);
      return '';
    }
  }

  Future<bool> checkEmailExsist(String email) async {
    try {
      final authResult =
          await _auth.signInWithEmailAndPassword(email: email, password: '');
      authResult.user!.delete();
      return false;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return true;
      } else {
        print(e.message);
        return false;
      }
    }
  }
}
