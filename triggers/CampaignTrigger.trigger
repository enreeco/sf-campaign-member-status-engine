/**
 * @author Enrico Murru (https://enree.co, @enreeco)
 * @description Creates CampaignMemberStatus records based on custom metadata object configuration
 */
trigger CampaignTrigger on Campaign (after insert) {
    CampaignTriggerHandler.execute();
}