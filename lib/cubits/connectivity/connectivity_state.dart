import 'package:equatable/equatable.dart';

abstract class ConnectivityState extends Equatable {
  const ConnectivityState();

  @override
  List<Object?> get props => [];
}

class ConnectivityInitial extends ConnectivityState {}

class ConnectivityConnected extends ConnectivityState {
  final bool wasOffline;

  const ConnectivityConnected({this.wasOffline = false});

  @override
  List<Object?> get props => [wasOffline];
}

class ConnectivityDisconnected extends ConnectivityState {
  const ConnectivityDisconnected();
}

