package org.oscarehr.hospitalReportManager.model;

import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;

import org.oscarehr.common.model.AbstractModel;

public class HRMCategory extends AbstractModel<Integer> {
	@Id
	@GeneratedValue(strategy = GenerationType.IDENTITY)
	private Integer id;
	private String categoryName;
	
	public HRMCategory(){
		
	}
	
	@Override
    public Integer getId() {
	    return id;
    }

	public String getCategoryName() {
    	return categoryName;
    }

	public void setCategoryName(String categoryName) {
    	this.categoryName = categoryName;
    }
	
	
}