import '../models/found_item_registration.dart';

abstract class FoundItemRepository {
  Future<String> registerFoundItem(FoundItemRegistration item);
}

class MockFoundItemRepository implements FoundItemRepository {
  const MockFoundItemRepository();

  @override
  Future<String> registerFoundItem(FoundItemRegistration item) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return 'mock-${item.createdAt.millisecondsSinceEpoch}';
  }
}

// Firebase 담당자는 이 인터페이스만 구현해서 FoundRegisterPage에 주입하면 됩니다.
// 예: collection('found_items').add(item.toMap())
