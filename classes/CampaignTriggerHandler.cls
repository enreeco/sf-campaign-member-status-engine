/**
 * @author Enrico Murru (https://enree.co, @enreeco)
 * @description Creates CampaignMemberStatus records based on custom metadata object configuration
 */
public class CampaignTriggerHandler {
        
    public static void execute(){
        //new statuses to be created / updated (with default or responded)
        List<CampaignMemberStatus> defaultOrRespondedStatuses = new List<CampaignMemberStatus>();
        //new statuses to be created / updated (without default or responded)
        List<CampaignMemberStatus> otherStatuses = new List<CampaignMemberStatus>();
        //statuses to be deleted
        List<CampaignMemberStatus> deleteStatusesList = new List<CampaignMemberStatus>();
        
        //selected campaigns
        List<Campaign> cmpList = new List<Campaign>();
        //record types
        List<ID> rTypesList = new List<ID>();
        
        //select only campaigns that are inserted or that changed their record types
        for(Integer i = 0; i < Trigger.new.size(); i++){
            Campaign nCmp = (Campaign)Trigger.new[i];
            if(!Trigger.isInsert
                && nCmp.RecordTypeId == ((Campaign)Trigger.old[i]).RecordTypeId) continue;
            cmpList.add(nCmp);
            rTypesList.add(nCmp.RecordTypeId);
        }
        
        if(cmpList.isEmpty()) return;
        
        //delete standard statuses
        deleteStatusesList = [SELECT Id, Label, CampaignId, IsDefault, HasResponded 
                              From CampaignMemberStatus 
                              Where CampaignId IN :cmpList
                              Order By Label];
        
        //query record types
        Map<ID, Recordtype> rTypeMap = new Map<ID,RecordType>([Select Id, DeveloperName From RecordType 
                                                              Where SObjectType = 'Campaign'
                                                              and Id IN :rTypesList]);
    	
        for(Campaign cmp : cmpList){
			
            //we can do as many query as we want with custom metadata
        	for(CampaignMemberStatusConfiguration__mdt cmsc : [SELECT Id, RecordTypeDeveloperName__c, 
                                                            StatusValue__c, SortOrder__c,IsDefault__c, Responded__c 
                                                            FROM CampaignMemberStatusConfiguration__mdt
                                                            WHERE RecordTypeDeveloperName__c = :rTypeMap.get(cmp.RecordTypeId).DeveloperName
                                                            ORDER BY StatusValue__c, IsDefault__c DESC, Responded__c DESC]){

				//gets CMS with same label (avoid duplicates on upsert)
				CampaignMemberStatus oldCMS = null;
				for(Integer ci = deleteStatusesList.size()-1; ci >= 0; ci--){
                    CampaignMemberStatus cms = deleteStatusesList[ci];
					if(cms.CampaignId != cmp.Id) continue;
                    if(cms.Label == cmsc.StatusValue__c){
                        oldCMS = cms;
                        deleteStatusesList.remove(ci);
                        break;
                    }
				}
                                                                
				CampaignMemberStatus newCMS = new CampaignMemberStatus(Label = cmsc.StatusValue__c,
                                                             SortOrder = cmsc.SortOrder__c.intValue(),
                                                             IsDefault = cmsc.IsDefault__c,
                                                             HasResponded = cmsc.Responded__c);
				if(oldCMS != null){
                    newCMS.Id = oldCMS.Id;
                }else{
                    newCMS.CampaignId = cmp.Id;
                }
				if(!newCMS.IsDefault 
                   && !newCMS.HasResponded){
					otherStatuses.add(newCMS);
				}else{
                	defaultOrRespondedStatuses.add(newCMS);            
				}
			}
        }
		//this DML sequence guarantees no conflicts
        upsert defaultOrRespondedStatuses;
        delete deleteStatusesList;
        upsert otherStatuses;
        
    }
}