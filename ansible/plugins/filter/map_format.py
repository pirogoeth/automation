#!/usr/bin/env python3
"""
Custom Ansible filter plugin for mapping format operations.

This provides a more intuitive way to apply string formatting to each item in a list,
which is what the built-in format filter should do when used with map() but doesn't.
"""

from ansible.errors import AnsibleFilterError


def map_format(items, format_string):
    """
    Apply string formatting to each item in a list.
    
    Args:
        items: List of items to format
        format_string: Format string (e.g., '{0}:2377')
    
    Returns:
        List of formatted strings
        
    Example:
        - name: Format IP addresses with port
          debug:
            msg: "{{ swarm_manager_nodes | map_format('{0}:2377') }}"
    """
    if not isinstance(items, list):
        raise AnsibleFilterError("map_format expects a list as input")
    
    if not isinstance(format_string, str):
        raise AnsibleFilterError("map_format expects a string as format_string")
    
    try:
        return [format_string.format(item) for item in items]
    except (ValueError, TypeError) as e:
        raise AnsibleFilterError(f"Error formatting items: {e}")


class FilterModule(object):
    """Ansible filter plugin class."""
    
    def filters(self):
        """Return the filter functions."""
        return {
            'map_format': map_format,
        }
