#!/usr/bin/env -S uv run
# -*- coding: utf-8 -*-
# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "click",
#     "halo",
#     "mitogen",
# ]
# ///

# from __future__ import annotations

import io
import logging
import os
import sys

import mitogen.core
import mitogen.master
import mitogen.select
import mitogen.utils

logger = logging.getLogger(__name__)


class Target:
    """ Target host
    """

    """ Name of the host to connect to. """
    # hostname: str
    hostname = None

    """ Context used to call functions on the host. """
    # context: mitogen.parent.Context
    context = None

    """ Receiver pipe the target delivers lines to. """
    # receiver: mitogen.core.Receiver
    receiver = None

    # def __init__(self, hostname: str):
    def __init__(self, hostname):
        self.hostname = hostname

    # def setup(self, router: mitogen.core.Router, sudo_as: Optional[str]=None, **kw):
    def setup(self, router, sudo_as=None, **kw):
        self.context = router.ssh(hostname=self.hostname, python_path=["/usr/bin/env", "python3"], **kw)
        if sudo_as is not None:
            self.context = router.sudo(username=sudo_as, via=self.context)
        self.receiver = mitogen.core.Receiver(router)
        self.receiver.target = self


# def stream_to(sender: mitogen.core.Sender, path: str, seek_offset: int = 0, seek_whence: str = "SEEK_END"):
def stream_to(sender, path, seek_offset = 0, seek_whence = "SEEK_END"):
    """ Streams the file at path to sender. """

    if not os.path.exists(path):
        # logger.error(f"File {path} does not exist on {sender.receiver.target.hostname}")
        logger.error("File {path} does not exist on {host}".format(path=path, host=sender.receiver.target.hostname))
    elif not os.path.isfile(path):
        # logger.error(f"Item at {path} is not a file on {sender.receiver.target.hostname}")
        logger.error("Item at {path} is not a file on {host}".format(path=path, host=sender.receiver.target.hostname))

    oswhence = {"SEEK_SET": io.SEEK_SET, "SEEK_CUR": io.SEEK_CUR, "SEEK_END": io.SEEK_END}[seek_whence]
    # logger.debug(f"Opening {path} to read from {whence}")
    logger.info("Opening {path} to read from {whence}".format(path=path, whence=seek_whence))
    with io.open(path, mode="rb") as source:
        source.seek(seek_offset, oswhence)
        while source.readable():
            line = source.readline()
            if line != b"":
                sender.send(line)

    sender.close()

# def stream_from(selector: mitogen.select.Select):
def stream_from(selector):
    """ Streams file data from a select to stdout. """

    while True:
        msg = selector.get()
        line = msg.unpickle().rstrip().decode(encoding="utf-8", errors="ignore")
        # print(f"{msg.receiver.target.hostname}: {line}")
        print("{host}: {line}".format(host=msg.receiver.target.hostname, line=line))


def main():
    import click
    from halo import Halo

    @click.command()
    @click.option("-H", "--host", type=str, help="Hostname to tail on, can be specified multiple times", multiple=True)
    @click.option("--hosts-stdin/--no-hosts-stdin", type=bool, help="Read a list of newline-delimited hosts from stdin")
    @click.option("-p", "--path", type=str, help="Path to tail", required=True)
    @click.option("--seek-offset", type=int, help="Byte offset to seek in the file", default=0)
    @click.option("--seek-whence", type=click.Choice(["SEEK_SET", "SEEK_END"]), default="SEEK_END")
    @click.option("--sudo-as", type=str, help="User to sudo to for reading")
    @click.option("--debug/--no-debug", type=bool, help="Whether debug logging should be turned on", default=False)
    # def main(host: List[str], hosts_stdin: bool, path: str, seek_offset: int, seek_whence: str, sudo_as: Optional[str]=None, debug: bool=False):
    def _main(host, hosts_stdin, path, seek_offset, seek_whence, sudo_as=None, debug=False):
        log_level = "DEBUG" if debug else "INFO"
        log_level = logging._nameToLevel[log_level]

        logging.basicConfig(level=log_level, stream=sys.stderr, format="[%(levelname)s] [%(asctime)s] %(message)s")

        try:
            broker = mitogen.master.Broker()
            router = mitogen.master.Router(broker=broker)

            connect_hosts = []
            if hosts_stdin:
                while not sys.stdin.closed:
                    line = sys.stdin.readline()
                    # if the line, BEFORE STRIPPING, is empty string, it's an EOF.
                    if line != "":
                        connect_hosts.append(line.strip())
                    else:
                        break
            else:
                connect_hosts = host

            logger.debug("Connecting to hosts {hosts}".format(hosts=connect_hosts))

            targets = []
            with Halo(text="Connecting to hosts...", spinner="dots") as progress:
                for _host in connect_hosts:
                    progress.text = "Connecting {host}".format(host=_host)
                    try:
                        target = Target(hostname=_host)
                        target.setup(router, sudo_as=sudo_as)
                        targets.append(target)
                    except Exception as err:
                        progress.fail(text=str(err))
                        logger.exception("Error while connecting to host {host}".format(host=_host))

                progress.succeed(text="Connected to {count} hosts!".format(count=len(targets)))

            # Attach a select to all target receivers
            select = mitogen.select.Select(oneshot=False)
            [select.add(target.receiver) for target in targets]

            # Get all target hosts started streaming logs through the receiver.
            calls = []
            for target in targets:
                logger.info("Start tailing on {host}".format(host=target.hostname))
                sender = target.receiver.to_sender()
                call = target.context.call_async(stream_to, sender, path, seek_offset=seek_offset, seek_whence=seek_whence)
                call.target = target
                calls.append(call)

            try:
                logger.info("Start streaming from children")
                stream_from(select)
            except KeyboardInterrupt:
                pass
        finally:
            logger.info("Shutting down")
            broker.shutdown()
            broker.join()

    _main()

main()
