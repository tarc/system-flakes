{
  ...
}:
(final: prev: {
  weechat = prev.weechat.override {
    configure = { ... }: {
      scripts = with prev.weechatScripts; [
        wee-slack
      ];
    };
  };
})
