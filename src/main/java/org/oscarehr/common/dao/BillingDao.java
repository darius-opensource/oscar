/**
 * Copyright (c) 2007-2008. CAISI, Toronto. All Rights Reserved.
 * This software is published under the GPL GNU General Public License. 
 * This program is free software; you can redistribute it and/or 
 * modify it under the terms of the GNU General Public License 
 * as published by the Free Software Foundation; either version 2 
 * of the License, or (at your option) any later version. * 
 * This program is distributed in the hope that it will be useful, 
 * but WITHOUT ANY WARRANTY; without even the implied warranty of 
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the 
 * GNU General Public License for more details. * * You should have received a copy of the GNU General Public License 
 * along with this program; if not, write to the Free Software 
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. * 
 * 
 * This software was written for 
 * CAISI, 
 * Toronto, Ontario, Canada 
 */

package org.oscarehr.common.dao;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;

import javax.persistence.Query;

import org.oscarehr.common.model.BillingONCHeader1;
import org.springframework.stereotype.Repository;
/**
*
* @author Eugene Katyukhin
*/

@Repository
public class BillingDao extends AbstractDao{

    public BillingDao() {
        super(BillingONCHeader1.class);
    }

    public BillingONCHeader1 getInvoice(Integer id) {
        return (entityManager.find(BillingONCHeader1.class, id));
    }


    
    public List<BillingONCHeader1> getAllInvoices(Integer demographicNo)
	{
    	StringBuilder sb=new StringBuilder();
		sb.append("select ch from BillingONCHeader1 ch");
		sb.append(" where ch.demographicNo=?1 and ch.pay_program='PAT'");
		sb.append(" order by ch.id");
		
		Query query = entityManager.createQuery(sb.toString());
		if (demographicNo!=null) query.setParameter(1, demographicNo);
		
		@SuppressWarnings("unchecked")
		List<BillingONCHeader1> results = query.getResultList();

		return results;
	}
    
    public Long getDebt(Integer demographicNo, Date billingDate) throws Exception {
    	StringBuilder sb=new StringBuilder();
		sb.append("SELECT SUM(total) - SUM(paid) FROM BillingONCHeader1 ch");
		sb.append(" WHERE ch.demographicNo=?1 AND ch.payProgram='PAT' AND (ch.status='P' OR ch.status='O') AND ch.billingDate <= ?2");
		Query query = entityManager.createQuery(sb.toString());
		if (demographicNo!=null) query.setParameter(1, demographicNo);
		if (billingDate!=null) query.setParameter(2, (new SimpleDateFormat("yyyy-MM-dd").format(billingDate)));
		
		String result = (String) query.getSingleResult();
		return (result != null ? Long.parseLong(result) : 0L);
    	
    }

    public List<Integer> listUnpaidInvoices(Integer demographicNo, Date billingDate) throws Exception {
    	StringBuilder sb=new StringBuilder();
		sb.append("SELECT id FROM BillingONCHeader1 ch");
		sb.append(" WHERE ch.demographicNo=?1 AND ch.payProgram='PAT' AND (ch.status='P' OR ch.status='O') AND ch.billingDate <= ?2 and ch.total<>ch.paid");
		Query query = entityManager.createQuery(sb.toString());
		if (demographicNo!=null) query.setParameter(1, demographicNo);
		if (billingDate!=null) query.setParameter(2, (new SimpleDateFormat("yyyy-MM-dd").format(billingDate)));
		
		@SuppressWarnings("unchecked")
		List<Integer> result = query.getResultList();
		return result;
    	
    }
}