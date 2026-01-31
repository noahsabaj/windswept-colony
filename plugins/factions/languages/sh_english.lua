--[[
    Factions Plugin - English Localization
]]--

NAME = "English"

LANGUAGE = {
    -- General
    noCharacter = "You do not have a character loaded.",
    notInFaction = "You are not in a faction.",
    noClass = "You do not have a class assigned.",
    noPermission = "You do not have permission to do that.",

    -- Class management
    classCreated = "Created class '%s' at rank %d.",
    classUpdated = "Updated %s for class '%s'.",
    classDeleted = "Deleted class '%s'.",
    classNotFound = "Class '%s' not found.",
    classNameExists = "A class with the name '%s' already exists.",
    classFull = "That class is at capacity.",
    classHasMembers = "Cannot delete a class with %d member(s). Reassign them first.",
    classCreateFailed = "Failed to create the class.",
    classUpdateFailed = "Failed to update the class.",
    classDeleteFailed = "Failed to delete the class.",

    -- Class restrictions
    cannotDeleteAnchor = "Cannot delete an anchor (leader) class.",
    cannotDeleteDefault = "Cannot delete the default entry class.",
    cannotRenameAnchor = "Cannot rename an anchor (leader) class.",
    cannotChangeRank = "Cannot change the rank of anchor or default classes.",
    cannotAffectRank = "You cannot affect classes at or above your rank.",
    cannotAffectCurrentRank = "You cannot reassign someone whose current rank is at or above yours.",
    cannotAssignToRank = "You cannot assign members to a rank at or above yours.",
    cannotInviteToRank = "You cannot invite to a class at or above your rank.",
    cannotRemoveHigherRank = "You cannot remove someone whose rank is at or above yours.",
    cannotRemoveSelf = "You cannot remove yourself. Use /factionresign instead.",

    -- Rank validation
    rankTooHigh = "The rank is too high. Maximum you can set: %d.",
    rankTooLow = "Rank must be at least 1 (0 is reserved for default class).",
    rankOutOfRange = "Rank must be between 1 and 254.",

    -- Input validation
    invalidClassName = "Class name must be between 2 and 32 characters.",
    invalidClassNameChars = "Class name can only contain letters, numbers, and spaces.",
    invalidPay = "Pay must be a valid number.",
    invalidRank = "Rank must be a valid number.",
    invalidLimit = "Limit must be a valid number.",
    invalidProperty = "Unknown property: %s. Valid: name, pay, rank, description, limit.",

    -- Permission management
    permGranted = "Granted '%s' permission to class '%s'.",
    permRevoked = "Revoked '%s' permission from class '%s'.",
    permGrantFailed = "Failed to grant the permission.",
    permRevokeFailed = "Failed to revoke the permission.",
    invalidPermission = "Invalid permission: %s.",
    cannotGrantPermYouDontHave = "You cannot grant the '%s' permission because you don't have it.",
    cannotModifyAnchorPerms = "Anchor class permissions cannot be modified (always has all permissions).",
    cannotModifyDefaultPerms = "Default class permissions cannot be modified (always has no permissions).",

    -- Faction membership
    alreadyInFaction = "You are already in a faction.",
    targetInOtherFaction = "That player is already in another faction. They must be removed first.",
    notInYourFaction = "That player is not in your faction.",
    characterNotOnline = "That character is not online.",
    noDefaultClass = "This faction has no default entry class configured.",

    -- Faction invites
    inviteSent = "Faction invite sent to %s.",
    joinedFaction = "You have joined %s as %s.",
    classNoLongerExists = "That class no longer exists.",
    factionNoLongerExists = "That faction no longer exists.",
    classFactionMismatch = "That class does not belong to that faction.",

    -- Faction removal
    removedFromFaction = "You have been removed from your faction.",
    memberRemoved = "Removed %s from the faction.",

    -- Class assignment
    classAssigned = "You have been assigned to %s.",
    memberAssigned = "Assigned %s to class %s.",

    -- Resignation
    resigned = "You have resigned from your faction.",
    resignedNoSuccessor = "You have resigned. The faction now has no leader.",
    resignedVoteStarted = "You have resigned. A succession vote has been started.",

    -- Succession
    successorNotFound = "Could not find that successor in your faction.",
    becameLeader = "You have become the %s.",
    autoPromoted = "You have been automatically promoted to %s.",
    electedLeader = "Congratulations! You have been elected as %s.",

    -- Voting
    voteReminder = "Reminder: There is an active succession vote in your faction. Visit a ballot station to vote.",
    droppedFromVote = "You have dropped out of the succession race.",
    notACandidate = "You are not a candidate in any active succession vote.",
    ballotSubmitted = "Your ballot has been submitted.",
    alreadyVoted = "You have already cast your vote.",
    voteNoLongerActive = "That vote is no longer active.",
    prisonersCannotVote = "Prisoners cannot vote.",
}
