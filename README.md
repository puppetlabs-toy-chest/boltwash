# boltwash

A [Wash](https://puppetlabs.github.io/wash/) plugin for Bolt's inventory. It presents groups and
targets in the inventory, and enables SSH access to them.

## Installation and configuration

1. `gem install boltwash`
2. Get the path to the boltwash script with `gem contents boltwash`.
3. Add to `~/.puppetlabs/wash/wash.yaml`

    ```yaml
    external-plugins:
        - script: '/path/to/boltwash/bolt.rb'
    ```

4. (Optional) Specify the path to a Boltdir in `~/.puppetlabs/wash/wash.yaml`. If not set,
   will use Bolt's default location at `~/.puppetlabs/bolt`.

    ```yaml
    bolt:
      dir: /path/to/boltdir
    ```

5. Enjoy!

> The `bolt` executable is included to make it easy to test from source. Run `bundle install`, then
> set `script: /path/to/boltwash/bolt`.
