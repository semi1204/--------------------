import 'package:flutter_bloc/flutter_bloc.dart';

enum LoginButtonState { idle, loading }

abstract class LoginButtonEvent {}

class TriggerLoginButtonEvent extends LoginButtonEvent {
  final bool isLoading;
  TriggerLoginButtonEvent(this.isLoading);
}

class LoginButtonBloc extends Bloc<LoginButtonEvent, LoginButtonState> {
  LoginButtonBloc() : super(LoginButtonState.idle) {
    on<TriggerLoginButtonEvent>((event, emit) {
      emit(event.isLoading ? LoginButtonState.loading : LoginButtonState.idle);
    });
  }
}
