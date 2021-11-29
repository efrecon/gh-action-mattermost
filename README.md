# gh-action-mattermost

This implements a curl/sh-based action to send Mattermost notifications. The
action provides for access to most of the parameters supported by incoming
[webhooks] and provides automatic GitHub, workflow and runner information
through the `card` mechanism. This information will be accessible from the
**info** icon displayed alongside the post.

  [webhooks]: https://developers.mattermost.com/integrate/incoming-webhooks/

## Usage

This action is designed to have good defaults. It will fail when some of
required fields are not provided or when notification failed. Most inputs have
the same name as the official [parameters]. For a complete list of all inputs,
see [action.yml](./action.yml).

In its default behaviour, this action will:

+ Fail until you have at least provided a `url` and `text` field.
+ Arrange for the icon of the sender to be the GitHub icon.
+ Arrange for the name of the sender to be `GitHub Action`.
+ Send the message to the default channel that is associated to the hook.
+ Add an information card with [context] information to identify what caused the
  message more easily. No sensitive information is passed through the card.

  [parameters]: https://developers.mattermost.com/integrate/incoming-webhooks/#parameters
  [context]: https://docs.github.com/en/actions/learn-github-actions/contexts

### Send a Test Message

The following workflow step would send a test message to the default channel.

```yaml
-
  uses: Mitigram/gh-action-mattermost@main
  with:
    url: http://{your-mattermost-site}/hooks/xxx-generatedkey-xxx
    text: This is a test message
```

### Send Multi-Line Markdown

Mattermost supports [Markdown] for the formatting of messages. In Markdown, line
breaks have some semantic (next paragraph, bullet-list items, etc.). However, in
the text passed to the Mattermost API through this action, line breaks should
appear as the character sequence `\n`. In order to write multi-line messages,
you will have to avoid YAML [block] scalars that preserve the line breaks, i.e.
use `>-` at the beginning of your blocks and manually write the `\n` whenever
necessary, as in the following example:

```yaml
-
  uses: Mitigram/gh-action-mattermost@main
  with:
    url: http://{your-mattermost-site}/hooks/xxx-generatedkey-xxx
    text: >-
      This is a multi-line message, introducing a bullet point list, meaning
      that a blank line prior the start of the bullet list is preferred.\n\n
      + One item\n
      + Another item\n
```

  [Markdown]: https://docs.mattermost.com/messaging/formatting-text.html
  [block]: https://yaml-multiline.info/

### Increased Verbosity

The `options` action input can be used to provide more options to the internal
wrapper implementation. You can use `-v` to increase verbosity.

```yaml
steps:
  uses: Mitigram/gh-action-mattermost@main
  with:
    url: http://{your-mattermost-site}/hooks/xxx-generatedkey-xxx
    text: This is a test message
    options: -v
```

## Developer Notes

You can use the testing [workflow.yml](./workflow.yml) in combination with [act]
to manually test this action. Provided [act] is installed, the following
command, run from the root directory, would exercise this action:

```console
act -b -W . -j test
```

Running [act] through [dew] is possible if you do not want to install [act] in
your environment. Just replace `act` with `dew act` in the command above.

  [act]: https://github.com/nektos/act
  [dew]: https://github.com/efrecon/dew
