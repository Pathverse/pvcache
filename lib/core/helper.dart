class PVCacheProxy {
  final String _env;

  PVCacheProxy(PVCacheHelper helper) : _env = helper.pvcConfig["env"];

  

}

class PVCacheHelper {
  final Map<String, dynamic> pvcConfig = Map.unmodifiable({
    "env" : "{env}"
  });
  late final PVCacheProxy pvc = PVCacheProxy(this);
}
