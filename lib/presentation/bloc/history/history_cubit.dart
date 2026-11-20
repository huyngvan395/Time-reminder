import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/history_log.dart';
import '../../../domain/repositories/reminder_repository.dart';

class HistoryState extends Equatable {
  final List<HistoryLog> logs;
  final bool isLoading;

  const HistoryState({this.logs = const [], this.isLoading = false});

  @override
  List<Object?> get props => [logs, isLoading];
}

class HistoryCubit extends Cubit<HistoryState> {
  final ReminderRepository _repository;

  HistoryCubit(this._repository) : super(const HistoryState(isLoading: true));

  Future<void> loadHistory() async {
    emit(HistoryState(logs: state.logs, isLoading: true));
    final logs = await _repository.getHistoryLogs();
    emit(HistoryState(logs: logs, isLoading: false));
  }

  Future<void> clearHistory() async {
    await _repository.clearHistoryLogs();
    emit(const HistoryState(logs: [], isLoading: false));
  }
}
