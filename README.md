# xr

`xr` é um CLI pequeno para reduzir atrito no track Ruby do Exercism.

## Fluxo principal

```bash
xr new assembly-line
xr test
xr irb
xr edit
xr submit
```

O estado do exercício atual é salvo em TOML:

```text
~/.local/state/xr/state.toml
```

Exemplo:

```toml
track = "ruby"
exercise = "assembly-line"
path = "/home/hvpaiva/exercism/ruby/assembly-line"
updated_at = "2026-05-05T12:00:00Z"
```

## Comandos

```bash
xr new <exercise>       # baixa, salva como atual e abre o editor
xr edit [exercise]      # abre o editor no exercise
xr test [exercise]      # roda ruby -r minitest/pride *_test.rb
xr irb [exercise]       # abre irb -r ./<solution>.rb --simple-prompt
xr submit [exercise]    # submete o arquivo .rb da solução
xr use <exercise>       # salva um exercise já baixado como atual
xr current              # mostra o exercise atual
xr path [exercise]      # imprime o path do exercise
xr list                 # lista exercises baixados
xr clear                # limpa o estado salvo
```

## Configuração por ambiente

```bash
XR_ROOT=~/exercism/ruby      # diretório dos exercícios
XR_TRACK=ruby                # track do Exercism
XR_EDITOR=nvim               # editor para xr new/edit
XR_STATE=~/.local/state/xr/state.toml
```

## Instalação local depois

Durante desenvolvimento:

```bash
/home/hvpaiva/dev/personal/xr/bin/xr help
```

Quando quiser instalar como comando global:

```bash
ln -sf /home/hvpaiva/dev/personal/xr/bin/xr ~/.local/bin/xr
```
