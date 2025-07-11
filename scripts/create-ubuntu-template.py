#!/usr/bin/env python3
# vim: set ai et ts=4 sts=4 sw=4:
# -*- coding: utf-8 -*-

import argparse
import dataclasses
import functools
import json
import operator
import re
import shutil
import subprocess
import sys
import textwrap
from argparse import ArgumentParser, Namespace
from collections import namedtuple
from datetime import datetime
from pprint import pprint
from typing import Callable, Dict, List, NewType, Optional

from future import annotations

CommandFunction = NewType("CommandFunction", Callable[[Namespace], None])


def command_name(name: str):
    """ Marks a command_name property on a function, used when building subcommands list. """

    def _command_name_inner(fn):
        fn.command_name = name
        return fn

    return _command_name_inner


@command_name("get-matching-items")
def _cmd_get_matching_items(argp: ArgumentParser) -> CommandFunction:
    """
        Returns all items from the keychain that match a set of criteria. Multiple types of criteria can be combined. 
        Excludes secret values by default. If secret values are included via -S, Keychain Access will prompt (at least on the first run)
        for your keychain password _for every keychain item that is to be returned_.
    """

    argp.add_argument("-aS", "--match-attr", help="Static string matching (key=value)", action="append", default=None)
    argp.add_argument("-aR", "--match-attr-regex", help="Regex search matching (key=/regex/)", action="append", default=None)
    argp.add_argument("-S", "--include-secrets", help="Include secrets for matched items", action="store_true", default=False)

    argp.formatter_class = argparse.RawDescriptionHelpFormatter
    argp.epilog = textwrap.dedent(f"""
        details:
            Calls to {_security or "security binary"} to find any keychain items matching the given specifiers.
            Matching specifiers should be in "key=value" (-aS) format or "key=/regex/[flags]" (-aR) format.
            Multiple matchers can be provided to each -aS and -aR to narrow the search. 
            Standard re library flags can be passed at the end of an -aR specifier, most useful being i (case-insensitive)

        examples:
            find all entries that have a label (attribute {A_LABEL}) of "TablePlus"
                > keychaintool.py get-matching-items -aS '{A_LABEL}=TablePlus'

            find all entries that have a label of "TablePlus" and an account ending in "_database"
                > keychaintool.py get-matching-items -aS '{A_LABEL}=TablePlus' -aR '{A_ACCT}=/.*_database$/'

            find all entries that have a label of "TablePlus" and an account ending in "_safe_mode", outputting their secrets
                > keychaintool.py get-matching-items -aS '{A_LABEL}=TablePlus' -aR '{A_ACCT}=/.*_safe_mode$/' -S

            find all entries matching "tableplus" with a case-insensitive regex:
                > keychaintool.py get-matching-items -aR '{A_LABEL}=/tableplus/i'
    """)

    def action_fn(args: Namespace):
        criteria = []
        criteria.extend(parse_value_attr_matchers(args.match_attr or []))
        criteria.extend(parse_regex_attr_matchers(args.match_attr_regex or []))

        if len(criteria) == 0:
            print("no matchers provided, just use get-keychain-items if you want everything!")
            exit(0)

        keychain_path = args.keychain_path
        for item in get_keychain_items(keychain_path):
            if all([criterion(item) for criterion in criteria]):
                if args.include_secrets:
                    # get_secret() stores the secret on the KeychainItem dataclass, so will be included in dataclasses.asdict()
                    item.get_secret()

                out = dataclasses.asdict(item)
                if not args.include_secrets:
                    out.pop("secret")

                print(json.dumps(out))

    return action_fn


def main():
    parser = ArgumentParser(
        prog="manage-ubuntu-template.py",
        description="Creates an Ubuntu template image to run on Proxmox",
    ) 
    # Global arguments
    parser.add_argument("-k", "--keychain-path", default=get_login_keychain())
    
    # Subcommands
    subcommands = [
        _cmd_get_keychain_items,
        _cmd_get_login_keychain_path,
        _cmd_get_matching_items,
        _cmd_update_matching_items,
        _cmd_import_json_items,
    ]
    subparser = parser.add_subparsers(help="action to execute")
    for subcommand in subcommands:
        if not hasattr(subcommand, "command_name"):
            print(f"Subcommand function {subcommand} is missing @command_name decorator")
            continue

        cmd_doc = textwrap.dedent(subcommand.__doc__).splitlines()
        cmd_help = cmd_doc[0] or ""

        cmd = subparser.add_parser(subcommand.command_name, help=cmd_help)
        cmd.description = "\n".join(cmd_doc)
        cmd_fn = subcommand(cmd)
        cmd.set_defaults(func=cmd_fn)

    args = parser.parse_args(sys.argv[1:])
    if "func" not in args:
        parser.print_usage()
        exit(1)

    args.func(args)


main()
