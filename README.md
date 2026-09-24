# RebootCC

控制中心模組：點一下重新啟動 SpringBoard，長按展開選單，可選重新啟動 SpringBoard、Userspace Reboot 和安全模式。

- 需要 Dopamine（rootless）、[CCSupport](https://github.com/opa334/CCSupport)、PreferenceLoader。
- 在 iPhone 14 Pro、iOS 16.5.1、Dopamine 上實測。
- 安裝後到「設定 → 控制中心」加入 RebootCC。

## 使用

- **點一下**：執行 `sbreload`，重新啟動 SpringBoard。
- **長按**：展開選單。
  - 重新啟動 SpringBoard
  - Userspace Reboot
  - 安全模式：建立 `/var/jb/basebin/.safe_mode` 後做 userspace reboot，重開後所有 tweak 都不會載入。這和 Dopamine 遇到 userspace panic 時進入的安全模式相同。要退出，到 Dopamine 的「設定」打開「Tweak Injection」，它會提示再做一次 userspace reboot。
- Userspace Reboot 和安全模式預設要點兩次：第一次點，副標題會變成「再點一次以確認」，4 秒內再點同一項才執行。可以在「設定 → RebootCC」關掉。

## 原理

模組跑在 SpringBoard 裡，身分是 mobile，所以做不了 userspace reboot，也寫不進 root 擁有的 `basebin`。這兩件事交給 setuid root 的 `/var/jb/usr/libexec/RebootCCHelper` 處理：

- Dopamine 會替 jbroot 裡的 setuid 二進位修正 uid，所以它能拿到 root。
- 拿到 root 後，它呼叫 `reboot3(RB2_USERREBOOT)`，這和 Dopamine 的 `jbctl reboot_userspace` 是同一個呼叫。
- 它只接受 `userspace` 和 `safemode` 兩個參數，也只替 mobile 和 root 執行。

## 建置

```sh
make clean package FINALPACKAGE=1
```

## License

© 2026 chxhua2k7. 根據[GNU GPL v3.0](LICENSE)授權：您可以使用、修改和重新分發此調整，但任何重新分發的版本（包括修改後的版本）都必須根據相同的授權發布，並且提供原始碼。
