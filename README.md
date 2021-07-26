# General

One part of the security flaw HiveNightmare or SeriusSAM is to delete Volume Shadow copies that contain the SAM database that the users can read.

This script will get all snapshots to a variable, then mount each of them and check the permission to the SAM database. If users have read access then we delete the snapshot.


