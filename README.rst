CROC Cloud API Client
============

Simple command-line utility for sending custom requests to CROC Cloud platform.

This is the bash version of c2-ec2 `client <https://github.com/C2Devel/c2-client>`_.

Prerequisites
-------------

Download CROC cloud api credentials - `doc <http://docs.website.cloud.croc.ru/en/manual/account.html#api>`_.

Populate ``c2rc.sh`` with appropriate values.

Evaluate script: ``source <path_to_c2rc.sh>``.

Usage
-----

Common request syntax:

.. code-block:: bash

   $ ./c2-ec2.sh <action> <arg1> <value1> <arg2> <value2>

Example
-------

Send simple request:

.. code-block:: bash

   $ ./c2-ec2.sh RunInstances ImageId cmi-078880A0 Description "Test instance" \
   InstanceType m1.small MaxCount 1 MinCount 1 SecurityGroup.1 test
