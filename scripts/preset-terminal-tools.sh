#!/bin/bash
set -e
#=================================================
# File name: preset-terminal-tools.sh
# System Required: Linux
# Version: 1.0
# Lisence: MIT
# Author: SuLingGG
# Blog: https://mlapp.cn
#=================================================
# ── 抗抖动：家用链路对新建立的 TLS 连接有约 10% 的瞬时失败率（GnuTLS handshake failed），
# 而全链路约有 40 处 git clone，不重试则几乎每轮都会静默丢包或整步失败，故对 clone 统一做有限重试。
# 只清理「本轮克隆新建出来」的目录，绝不触碰重试前就已存在的路径。
git() {
  if [ "${1:-}" != "clone" ]; then command git "$@"; return $?; fi
  local dest="${!#}" existed=0 n=0 rc=0
  case "$dest" in -*|http*|git@*|"") dest="" ;; esac
  if [ -n "$dest" ] && [ -e "$dest" ]; then existed=1; fi
  while :; do
    if command git "$@"; then
      return 0
    else
      rc=$?
    fi
    n=$((n + 1))
    if [ "$n" -ge 5 ]; then break; fi
    if [ -n "$dest" ] && [ "$existed" -eq 0 ] && [ -d "$dest" ]; then rm -rf -- "$dest"; fi
    echo "::warning::git clone 第 $n 次失败(rc=$rc)，5 秒后重试：${dest:-$*}" >&2
    sleep 5
  done
  return "$rc"
}
export -f git

mkdir -p files/root
pushd files/root

## Install oh-my-zsh
# Clone oh-my-zsh repository
git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh ./.oh-my-zsh

# Install extra plugins
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ./.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ./.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
git clone --depth=1 https://github.com/zsh-users/zsh-completions ./.oh-my-zsh/custom/plugins/zsh-completions

# Get .zshrc dotfile
cp "$GITHUB_WORKSPACE/scripts/.zshrc" .

popd

# Preload oh-my-zsh completion cache after boot so SSH logins stay fast.
mkdir -p files/etc/init.d files/etc/rc.d
cat > files/etc/init.d/zsh-preload <<'EOF'
#!/bin/sh /etc/rc.common

START=99

start() {
	(
		sleep 20
		[ -x /usr/bin/zsh ] || exit 0
		[ -r /root/.zshrc ] || exit 0
		HOME=/root USER=root SHELL=/usr/bin/zsh /usr/bin/zsh -i -c exit >/tmp/zsh-preload.log 2>&1
	) &
}
EOF
chmod 755 files/etc/init.d/zsh-preload
ln -sf ../init.d/zsh-preload files/etc/rc.d/S99zsh-preload
