import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 현재 로그인한 사용자 확인
  User? get currentUser => _auth.currentUser;

  // Google 로그인 및 Firebase 인증 연동
  Future<User?> signInWithGoogle() async {
    try {
      // 1. Google 팝업 창 띄우기
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // 사용자가 로그인을 취소한 경우
        return null;
      }

      // 2. 인증 세부 정보 획득
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Firebase 자격 증명(Credential) 생성
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Firebase Auth로 로그인
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      print('Google 로그인 에러: $e');
      rethrow;
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}