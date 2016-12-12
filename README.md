# basedef

A modular base defence system for [ComputerCraft](http://www.computercraft.info/).

Everything runs on the basedef server, and all devices (teslas, doors, mob detectors, etc..) all run the exact same client code.

The basedef server assigns devices IDs and sends code to the devices for them to execute (via the `device:remoteExecute` method).
This means devices don't need their own program, and all changes can be done from the central server.

Of course, if you so desired, you *could* write custom client software to run on the devices, and it'd be supported fine by basedef.


A wiki is planned with more information.
