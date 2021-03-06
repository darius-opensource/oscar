<%--

    Copyright (c) 2001-2002. Department of Family Medicine, McMaster University. All Rights Reserved.
    This software is published under the GPL GNU General Public License.
    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

    This software was written for the
    Department of Family Medicine
    McMaster University
    Hamilton
    Ontario, Canada

--%>

<%@ taglib uri="/WEB-INF/security.tld" prefix="security"%>
<%@ taglib uri="/WEB-INF/struts-bean.tld" prefix="bean" %>

<%@page import="org.oscarehr.util.SpringUtils,org.oscarehr.util.LocaleUtils,org.oscarehr.util.MiscUtils, oscar.util.DateUtils"%>
<%@page import="org.oscarehr.common.model.Demographic, org.oscarehr.common.model.BillingONItem, org.oscarehr.common.model.RaDetail"%>
<%@page import="java.util.Locale, java.math.BigDecimal, java.util.Calendar,java.util.List,java.util.ArrayList, java.util.HashMap, java.util.Map, java.util.Date"%>
<%@page import="java.text.ParseException"%>
<%@page import="org.oscarehr.common.model.BillingONPayment,org.oscarehr.common.dao.BillingONPaymentDao"%>
<%@page import="org.oscarehr.common.model.BillingONCHeader1,org.oscarehr.common.dao.BillingONCHeader1Dao"%>
<%@page import="org.oscarehr.common.model.BillingONExt,org.oscarehr.common.dao.BillingONExtDao"%>
<%@page import="org.oscarehr.common.model.Demographic,org.oscarehr.common.dao.DemographicDao"%>
<%@page import="org.oscarehr.common.model.Provider,org.oscarehr.PMmodule.dao.ProviderDao"%>
<%@page import="org.oscarehr.common.model.RaHeader,org.oscarehr.common.dao.RaHeaderDao"%>
<%@page import="org.oscarehr.common.model.RaDetail,org.oscarehr.common.dao.RaDetailDao"%>
<%@page import="org.oscarehr.common.model.BillingONPremium,org.oscarehr.common.dao.BillingONPremiumDao"%>
<%@page import="org.oscarehr.common.model.BillingONItem, org.oscarehr.common.service.BillingONService"%>

<%
    if(session.getAttribute("userrole") == null )  response.sendRedirect("../logout.jsp");
    String roleName$ = (String)session.getAttribute("userrole") + "," + (String) session.getAttribute("user");   
%> 

    <security:oscarSec roleName="<%=roleName$%>" objectName="_tasks" rights="r" reverse="true" >
        <%response.sendRedirect("../noRights.html");%>
    </security:oscarSec>

   
<%  
    boolean isTeamBillingOnly=false;
    boolean isThisProviderOnly=false; 
%>

    <security:oscarSec objectName="_team_billing_only" roleName="<%=roleName$ %>" rights="r" reverse="false">
        <% isTeamBillingOnly=true; %>
    </security:oscarSec>
    
    <security:oscarSec roleName="<%=roleName$%>" objectName="_admin.invoices" rights="r" reverse="false" >
        <% isThisProviderOnly=true; %>
    </security:oscarSec>

    <security:oscarSec objectName="_admin,_admin.billing" roleName="<%=roleName$ %>" rights="r" reverse="false">
        <% isThisProviderOnly=false; %>
    </security:oscarSec>

<%     
    Locale locale = request.getLocale();         
    Calendar cal = Calendar.getInstance();
    String today = DateUtils.formatDate(cal, locale);
              
    String startDateStr = request.getParameter("startDateText");
    if (startDateStr == null || startDateStr.isEmpty()) {
        cal.add(Calendar.MONTH, -1);
        startDateStr = DateUtils.formatDate(cal, locale);
    }
    
    String errorMsg = "";
    String endDateStr = request.getParameter("endDateText");
    if (endDateStr == null || endDateStr.isEmpty()) {
        endDateStr = today;
    }
    Date startDate =null;
    Date endDate = null;
    try {         
       startDate = DateUtils.parseDate(startDateStr, locale);
       endDate = DateUtils.parseDate(endDateStr, locale);
       if (DateUtils.calculateDayDifference(startDate, endDate) < 0) {
            errorMsg = LocaleUtils.getMessage(locale, "oscar.billing.paymentReceived.errorEndDateGreater");
        }
    }
    catch (java.text.ParseException e) {
        errorMsg = LocaleUtils.getMessage(locale, "oscar.billing.paymentReceived.errorOnDate");
    }
    
    
    
    //Get list of providers           
    String curProviderNo = (String) session.getAttribute("user"); 
    ProviderDao providerDao = (ProviderDao)SpringUtils.getBean("providerDao");
    Provider provider = providerDao.getProvider(curProviderNo);
    
    List<Provider> pList = null;
    
    if (isThisProviderOnly) {
        if (provider.getOhipNo().isEmpty()) 
            response.sendRedirect("../../../noRights.html");
        
        pList = new ArrayList<Provider>();        
        pList.add(provider);
    } else if (isTeamBillingOnly) {
        pList = providerDao.getBillableProvidersOnTeam(provider);
    } else {
        pList = providerDao.getBillableProviders();
    }
    
    BillingONPremiumDao bPremiumDao = (BillingONPremiumDao) SpringUtils.getBean("billingONPremiumDao");
    RaDetailDao raDetailDao = (RaDetailDao) SpringUtils.getBean("raDetailDao");
    BillingONCHeader1Dao bCh1Dao = (BillingONCHeader1Dao) SpringUtils.getBean("billingONCHeader1Dao");
    BillingONPaymentDao bPaymentDao = (BillingONPaymentDao) SpringUtils.getBean("billingONPaymentDao");
    BillingONExtDao bExtDao = (BillingONExtDao) SpringUtils.getBean("billingONExtDao");
    DemographicDao demographicDao = (DemographicDao) SpringUtils.getBean("demographicDao");    
    BillingONService billingONService = (BillingONService) SpringUtils.getBean("billingONService");
        
    List<RaDetail> raList = null;
    List<BillingONPremium> premiumList = null;
    List<BillingONCHeader1> ptList = null;
    
    String providerNo = request.getParameter("providerList");
        
    if (errorMsg.isEmpty() && providerNo != null) {  
                 
        Calendar raCalEndDate = Calendar.getInstance();
        Calendar raCalStartDate = Calendar.getInstance();
        
        //Only get OHIP numbers from the last month
	raCalStartDate.setTime(endDate);
	raCalEndDate.setTime(endDate);
		
	int firstDate = raCalStartDate.getActualMinimum(Calendar.DATE);
	int lastDate = raCalEndDate.getActualMaximum(Calendar.DATE);
		
	raCalStartDate.set(Calendar.DATE, firstDate);
	raCalEndDate.set(Calendar.DATE,lastDate);
		
	Date raStartDate = raCalStartDate.getTime();
	Date raEndDate = raCalEndDate.getTime();   
        
        if (providerNo.isEmpty()) {  
            raList = raDetailDao.getRaDetailByDate(raStartDate, raEndDate, locale);            
            ptList = bCh1Dao.get3rdPartyInvoiceByDate(startDate, endDate,locale);
            premiumList = bPremiumDao.getActiveRAPremiumsByPayDate(startDate, endDate, locale);
        } else {
            Provider p = providerDao.getProvider(providerNo);                       
            raList = raDetailDao.getRaDetailByDate(p, raStartDate, raEndDate, locale);
            ptList = bCh1Dao.get3rdPartyInvoiceByProvider(p, startDate, endDate,locale);
            premiumList = bPremiumDao.getActiveRAPremiumsByProvider(p, startDate, endDate, locale);
        }       
    }         
    
%>
<!DOCTYPE html>
<html>
    <head>
        <title><bean:message key="oscar.billing.paymentReceived.title"/></title>
        <link rel="stylesheet" type="text/css" media="all" href="../../../share/calendar/calendar.css" title="win2k-cold-1" /> 
        <script type="text/javascript" src="../../../share/calendar/calendar.js"></script>
        <script type="text/javascript" src="../../../share/calendar/lang/<bean:message key="global.javascript.calendar"/>"></script>                                                            
        <script type="text/javascript" src="../../../share/calendar/calendar-setup.js"></script>
        <script type="text/javascript">
            function popupPage(vheight,vwidth,varpage) {
              var page = "" + varpage;
              windowprops = "height="+vheight+",width="+vwidth+",location=no,scrollbars=yes,menubars=no,toolbars=no,resizable=yes,screenX=0,screenY=0,top=0,left=0";
              var popup=window.open(page, "billcorrection", windowprops);
                if (popup != null) {
                        if (popup.opener == null) {
                          popup.opener = self;
                        }
                    popup.focus();
                }
            }
        </script>                    
        <link rel="stylesheet" type="text/css" href="billingON.css" />
        <style type="text/css">
            h1 {padding-left:10px;padding-top:16px;padding-bottom:16px;text-align:left; font-weight: 900;font-size:16pt;font-family:arial,sans-serif;color:white;}
            h2 {font-weight: bold; font-family:arial, sans-serif;}
            h3 {font-family:arial, sans-serif;}
            h4 {color:red; font-weight:bold;font-family:arial, sans-serif;}
            thead {background-color:lightblue;}
	    th {padding-top:10px;padding-bottom:10px;font-weight: bold; font-size:9pt; font-family:arial,sans-serif;}
            td {font-family:arial,sans-serif}
        </style>
    </head>
    <body>
        <h1 class="myDarkGreen"><bean:message key="oscar.billing.paymentReceived.title"/></h1>
        <h2 style="padding-right:10px;text-align:right"><%=today%></h2>
        <h4><%=errorMsg%></h4>
        <form name="billingPaymentForm" method="get" action="billingONPayment.jsp">
                                  
            <table width="100%" class="myYellow">
                <tr>
                    <td colspan="2">                   
                        <h3 style="text-align:center"><bean:message key="oscar.billing.on.paymentReceived.freezePeriod"/></h3>
                    </td>
                </tr>
                <tr>
                    <td  style="padding-right:5px;text-align:right" ><a id="startDate" href="javascript: function myFunction() {return false; }"><bean:message key="oscar.billing.on.paymentReceived.startDate"/></a>
                        <input type="text" name="startDateText" id="startDateText" value="<%=DateUtils.formatDate(startDate,locale)%>"/>
                    </td>
                                        
                    <td  style="padding-left:5px;text-align:left" ><a id="endDate" href="javascript: function myFunction() {return false; }"><bean:message key="oscar.billing.on.paymentReceived.endDate"/></a>
                        <input type="text" name="endDateText" id="endDateText" value="<%=DateUtils.formatDate(endDate,locale)%>"/>
                    </td>
                </tr>
                <tr>
                    <td colspan="2" style="padding-top:10px;text-align:center"><bean:message key="oscar.billing.on.paymentReceived.providerName"/>
                    
                        <select name="providerList">
                    <%  if(pList.size() > 1) { %>
                            <option value=""><bean:message key="oscar.billing.on.paymentReceived.allproviders"/></option>
                    <%  } %>
    
                    <%  for (Provider p : pList) { 
                            String selected = "";                            
                            if (providerNo != null && providerNo.equals(p.getProviderNo())){
                                selected = "selected";
                            }
                    %>                    
                            <option <%=selected%> value="<%=p.getProviderNo()%>"><%=p.getLastName()%>, <%=p.getFirstName()%></option>
	            <%  } %>                 
                        </select>
                    </td>
                </tr>
                <tr>
                    <td colspan="2" style="padding-top:14px;text-align:center"><input type="submit" value="<bean:message key="oscar.billing.on.paymentReceived.generateReport"/>"/></td>
                </tr>
            </table>

            <h3><bean:message key="oscar.billing.on.paymentReceived.raBillingReport"/></h3>
            <table width="100%" cellspacing="0" class="myYellow">                
                    <thead>
			<tr>
                                <th><bean:message key="oscar.billing.on.paymentReceived.invoiceNumber"/></th>
                                <th><bean:message key="oscar.billing.on.paymentReceived.invoiceStatus"/></th>                                
		                <th><bean:message key="oscar.billing.on.paymentReceived.serviceDate"/></th>
                    		<th><bean:message key="oscar.billing.on.paymentReceived.demographicName"/></th>
                                <th><bean:message key="oscar.billing.on.paymentReceived.dxCode"/></th>
                    		<th><bean:message key="oscar.billing.on.paymentReceived.serviceCode"/></th>                    		
                    		<th><bean:message key="oscar.billing.on.paymentReceived.serviceCount"/></th>
                                <th><bean:message key="oscar.billing.on.paymentReceived.currentFee"/></th>
                    		<th><bean:message key="oscar.billing.on.paymentReceived.claimed"/></th>
                    		<th><bean:message key="oscar.billing.on.paymentReceived.paid"/></th>
                    		<th><bean:message key="oscar.billing.on.paymentReceived.adjustments"/></th>
                    		<th><bean:message key="oscar.billing.on.paymentReceived.payprogram"/></th>
                    		<th><bean:message key="oscar.billing.on.paymentReceived.claimNo"/></th>
                    		<th><bean:message key="oscar.billing.on.paymentReceived.errorCodes"/></th>
			</tr>
                    </thead>

    
                    <%
                        BigDecimal feeTotal = new BigDecimal("0.00");
                        BigDecimal claimTotal = new BigDecimal("0.00");
                        BigDecimal paidTotal = new BigDecimal("0.00");
                        BigDecimal adjTotal = new BigDecimal("0.00");  
                        int numItems = 0;  
                                                          
                        if (raList != null) {
                                            
                            String rowColor = "myWhite";   
                            int curBillingNo = 0;
                            BillingONItem b = null;
                            for (RaDetail rad : raList) {
                                                                                                                                                                                                                 
                                BillingONCHeader1 bCh1 = bCh1Dao.find(rad.getBillingNo());
                                if (bCh1 == null) {
                                    // Check to make sure there is actually a bill in this OSCAR instance 
                                    // that is associated with this RA detail
                                    continue;
                                }
                                
                                if (providerNo != null && !providerNo.isEmpty() && !bCh1.getProviderNo().equals(providerNo)) {
                                    // Check to make sure that the provider account associated with the bill matches the 
                                    // provider record we are searching on since it is not necessarily true:
                                    // radetail.providerOhipNo == provider.ohip_no && billing_on_cheader1.provider_no == provider.provider_no
                                    continue;
                                }
                                
                                numItems++;
                                int lastBillingNo = curBillingNo;
                                curBillingNo = rad.getBillingNo();
                                
                                String serviceCode = rad.getServiceCode();
                                BillingONItem bLast = b;
                                b = bCh1Dao.findBillingONItemByServiceCode(bCh1, serviceCode);
                                
                                boolean isSameBill = true;
                                
                                String dxCode = "";
                                String claimAmtStr = rad.getAmountClaim();
                                String bItemFee = "D";
                                if (b != null) {
                                    dxCode = b.getDx();                                    
                                    if (!b.getStatus().equals(BillingONItem.DELETED)) {
                                        bItemFee = b.getFee();
                                    }
                                                                    
                                    if (b.equals(bLast)) {                                    
                                        serviceCode = "";
                                        dxCode = "";
                                        bItemFee = "";                                    
                                    }
                                }
                                         
                                Integer demoNo = bCh1.getDemographicNo();   
                                Demographic d = demographicDao.getDemographicById(demoNo);
                                String demographicName = "";
                                String billStatus = "";
                                String serviceDate = "";
                                if (lastBillingNo != curBillingNo) {
                                    
                                    isSameBill = false;
                                    serviceDate = rad.getServiceDate();
                                    demographicName = d.getFormattedName(); 
                                    billStatus = bCh1.getStatus();                         
                                    
                                    if (rowColor.equals("myWhite")) 
                                        rowColor = "myPurple";                                        
                                    else 
                                        rowColor = "myWhite";                                                                                                  
                                }
                                                                                                           
                                BigDecimal feeAmt = new BigDecimal("0.00");
                                if (!bItemFee.isEmpty() && !bItemFee.equals("D")) {
                                   feeAmt = new BigDecimal(bItemFee);
                                }
                                
                                BigDecimal claimAmt = new BigDecimal(claimAmtStr);                               
                                BigDecimal paidAmt = new BigDecimal(rad.getAmountPay().trim());    
                                BigDecimal adjAmt = claimAmt.subtract(paidAmt);              

                                feeTotal = feeTotal.add(feeAmt);
                                claimTotal = claimTotal.add(claimAmt);
                                paidTotal = paidTotal.add(paidAmt);
                                adjTotal = adjTotal.add(adjAmt);  
                                                                                              
                                if ((feeAmt.compareTo(paidAmt) != 0) || (billStatus.equals(BillingONCHeader1.DELETED) && (paidAmt.compareTo(new BigDecimal("0.00")) != 0))) {
                                    rowColor = "myPink";
                                }
                                String curBillingNoStr = String.valueOf(curBillingNo);
                         %>
                    <tr class="<%=rowColor%>">
                        <% if (!isSameBill) {%>
                            <td style="text-align:center"><a href="#" onclick="popupPage(700,700,'billingONCorrection.jsp?billing_no=<%=curBillingNoStr%>');return false;"><%=curBillingNoStr%></a></td>                                               
                        <%}else {%>
                            <td></td>
                        <%}%>
                        <td style="text-align:center"><%=billStatus%></td>
                        <td style="text-align:center"><%=serviceDate%></td>
                        <% if (!isSameBill) {%>
                            <td style="text-align:center"><a href="#" onclick="popupPage(800,740,'../../../demographic/demographiccontrol.jsp?demographic_no=<%=demoNo%>&displaymode=edit&dboperation=search_detail');return false;"><%=demographicName%></a></td>
                        <%}else {%>
                            <td></td>
                        <%}%>
                        <td style="text-align:center"><%=dxCode%></td>
                        <td style="text-align:center"><%=serviceCode%></td>                       
                        <td style="text-align:center"><%=rad.getServiceCount()%></td>
                        <td style="text-align:right"><%=bItemFee%></td>
                        <td style="text-align:right"><%=claimAmtStr%></td>
                        <td style="text-align:right"><%=paidAmt.toPlainString()%></td>
                        <td style="text-align:right"><%=adjAmt.toPlainString()%></td>
                        <td style="text-align:center"><%=rad.getBillType()%></td>
                        <td style="text-align:center"><%=rad.getClaimNo()%></td>
                        <td style="text-align:center;font-weight:bold"><%=rad.getErrorCode()%></td>                       
                    </tr>
                    <%      }                                                       
                        }
                    %>
                <tr style="background-color:lightblue;">
                    <td colspan="2" style="font-weight:bold;"><bean:message key="oscar.billing.on.paymentReceived.itemCount"/>:</td>
                    <td colspan="4"><%=numItems%></td>
                    <td style="font-weight:bold"><bean:message key="oscar.billing.on.paymentReceived.cumulativeTotal"/>:</td>
                    <td style="text-align:right"><%=feeTotal%></td>
                    <td style="text-align:right"><%=claimTotal%></td>
                    <td style="text-align:right"><%=paidTotal%></td>
                    <td style="text-align:right"><%=adjTotal%></td>
                    <td colspan="5"></td>
                </tr>            
            </table>
                
            <!-- 3rd Party Payments Table -->
            <h3><bean:message key="oscar.billing.on.paymentReceived.premiumPaymentReport"/></h3>
            <table width="100%" cellspacing="0" class="myYellow">  
                <thead>
                    <tr>
                            <th style="text-align:left"><bean:message key="oscar.billing.on.paymentReceived.providerName"/></th> 
                            <th style="text-align:left"><bean:message key="oscar.billing.on.paymentReceived.payDate"/></th> 
                            <th colspan="9" style="text-align:right"><bean:message key="oscar.billing.on.paymentReceived.paid"/></th>                            
                    </tr>                   
                </thead>
                 <%       
                        int numPremiumItems = 0; 
                        String rowColor = "myWhite";   
                        BigDecimal totalPremiums = new BigDecimal("0.00");
                        
                        if (premiumList != null) {
                            for (BillingONPremium bPremium : premiumList) {

                                numPremiumItems++;

                                if (rowColor.equals("myWhite"))
                                        rowColor = "myPurple";
                                    else
                                        rowColor = "myWhite";

                                String amountPaid = "0.00";
                                try { 
                                     amountPaid = bPremium.getAmountPay();
                                } catch (NumberFormatException e) {
                                    MiscUtils.getLogger().warn("Premium Amount Paid not a number",e);
                                }
                                
                                String providerName = "";
                                String premProviderNo = bPremium.getProviderNo();
                                if (premProviderNo != null) {
                                    Provider p = providerDao.getProvider(premProviderNo); 
                                    if (p != null) {
                                        providerName = p.getFormattedName();
                                    }
                                 }

                                 Date payDate = bPremium.getPayDate();
                                 String payDateStr = DateUtils.formatDate(payDate, request.getLocale());
                  %>
                    <tr class="<%=rowColor%>">         
                        <td><%=providerName%></td>
                        <td><%=payDateStr%></td>
                        <td colspan="9" style="text-align:right"><%=amountPaid%></td>
                    </tr>
                  <%        totalPremiums = totalPremiums.add(new BigDecimal(amountPaid));
                            }
                        }%>
                  <tr style="background-color:lightblue;">
                        <td colspan="2" style="font-weight:bold;"><bean:message key="oscar.billing.on.paymentReceived.itemCount"/>:</td>
                        <td colspan="3"><%=numPremiumItems%></td>
                        <td style="font-weight:bold"><bean:message key="oscar.billing.on.paymentReceived.cumulativeTotal"/>:</td>
                        <td style="text-align:right;font-weight:bold"><%=totalPremiums.toPlainString()%></td>                       
                        <td colspan="4"></td>
                  </tr>
            </table>
                <!-- 3rd Party Payments Table -->
                <h3><bean:message key="oscar.billing.on.paymentReceived.3rdPartyBillingReport"/></h3>
                <table width="100%" cellspacing="0" class="myYellow">
                    <thead>
			<tr>
                                <th><bean:message key="oscar.billing.on.paymentReceived.invoiceNumber"/></th>
                    		<th><bean:message key="oscar.billing.on.paymentReceived.serviceDate"/></th>
                    		<th><bean:message key="oscar.billing.on.paymentReceived.demographicName"/></th>
                                <th><bean:message key="oscar.billing.on.paymentReceived.dxCode"/></th>
                                <th><bean:message key="oscar.billing.on.paymentReceived.serviceCode"/></th>
                                <th><bean:message key="oscar.billing.on.paymentReceived.serviceCount"/></th>
                                <th><bean:message key="oscar.billing.on.paymentReceived.billed"/></th>
                    		<th><bean:message key="oscar.billing.on.paymentReceived.paid"/></th>
                                <th><bean:message key="oscar.billing.on.paymentReceived.refund"/></th>                      		
                    		<th><bean:message key="oscar.billing.on.paymentReceived.paymentDate"/></th>
                    		<th><bean:message key="oscar.billing.on.paymentReceived.balanceOutstanding"/></th>
			</tr>
                    </thead>
                    
                    <%                        
                        BigDecimal total3rdPaid = new BigDecimal("0.00");
                        BigDecimal total3rdRefunded = new BigDecimal("0.00");
                        BigDecimal total3rdBilled = new BigDecimal("0.00");
                        final BigDecimal zeroAmt = new BigDecimal("0.00");
                        
                        int num3rdItems = 0;
                        if (ptList != null) {
                                                                                         
                            rowColor = "myWhite";   

                            for (BillingONCHeader1 bCh1 : ptList) {   
                                                            
                                List<BillingONPayment> bPayList = bPaymentDao.find3rdPartyPayRecordsByBill(bCh1, startDate, endDate);
                                BigDecimal totalPaid = BillingONPaymentDao.calculatePaymentTotal(bPayList);
                                BigDecimal totalRefunded = BillingONPaymentDao.calculateRefundTotal(bPayList);
                                
                                //make sure there were actually payments made in the date range specified on the bill in question
                                if ((totalPaid.compareTo(zeroAmt) != 0) || (totalRefunded.compareTo(zeroAmt) != 0)) { 
                                    num3rdItems++;                                                          

                                    if (rowColor.equals("myWhite"))
                                        rowColor = "myPurple";
                                    else
                                        rowColor = "myWhite";
                   %>
                   <tr class="<%=rowColor%>">
                   <%                                                             
                                    String billingDateStr = "";
                                    String demographicName = "";                                                                    

                                    billingDateStr = DateUtils.formatDate(bCh1.getBillingDate(), locale);

                                    Integer demoNo = bCh1.getDemographicNo();     
                                    Demographic d = demographicDao.getDemographicById(demoNo);
                                    demographicName = d.getFormattedName();
                                    String billingNo = String.valueOf(bCh1.getId());
                                    if (!isThisProviderOnly) {  %>                     
                                    <td style="text-align:center"><a href="#" onclick="popupPage(700,700,'billingONCorrection.jsp?billing_no=<%=billingNo%>');return false;"><%=bCh1.getId()%></a></td>
                    <%          } else { %>
                                    <td style="text-align:center"><%=billingNo%></td>
                    <%          } %>
                                 <td style="text-align:center"><%=billingDateStr%></td>
                                 <td style="text-align:center"><a href="#" onclick="popupPage(800,740,'../../../demographic/demographiccontrol.jsp?demographic_no=<%=demoNo%>&displaymode=edit&dboperation=search_detail');return false;"><%=demographicName%></a></td>                                
                    <%                                                   
                                    String dxCode = "";  
                                    String serviceCode = "";
                                    String serviceCount = "";
                                    String amtBilled = "";

                                    List<BillingONItem> bItems = billingONService.getNonDeletedInvoices(bCh1.getId());

                                    BigDecimal totalBilled = new BigDecimal("0.00");

                                    int numBillItems = 0;
                                    for (BillingONItem bItem : bItems) {
                                        dxCode = bItem.getDx();
                                        serviceCode = bItem.getServiceCode();
                                        serviceCount = bItem.getServiceCount();
                                        amtBilled = bItem.getFee();  
                                        try {
                                            totalBilled = totalBilled.add(new BigDecimal(amtBilled));
                                        } catch (NumberFormatException e) {
                                           MiscUtils.getLogger().warn("BillItem fee is not a valid amount:" + amtBilled); 
                                        }
                                        numBillItems++;

                                        if (numBillItems > 1) {
                     %>
                       </tr>
                       <tr class="<%=rowColor%>">
                                <td colspan="3"></td>
                    <%                  } %>
                                 <td style="text-align:center"><%=dxCode%></td>
                                 <td style="text-align:center"><%=serviceCode%></td>
                                 <td style="text-align:center"><%=serviceCount%></td>
                                 <td style="text-align:right"><%=amtBilled%></td>
				 <td colspan="4"></td>
                    
							                                          
                     <%             }     %>
                               </tr>
                                <tr class="<%=rowColor%>">
					<td colspan="6"></td>
                                        <td style="font-weight:bold;text-align:right"><%=totalBilled.toPlainString()%></td>

                     
                     <%                                    
                                    total3rdBilled = total3rdBilled.add(totalBilled);

                                    int numPayments = 0;
                                    for (BillingONPayment bPay : bPayList) {                                        
                                        BigDecimal payAmt = bExtDao.getPayment(bPay);
                                        BigDecimal refundAmt = bExtDao.getRefund(bPay);
                                        
                                        if ((payAmt.compareTo(zeroAmt)!=0) || (refundAmt.compareTo(zeroAmt)!=0)) {                                                                                    
                                            numPayments++;
                                            String payDate = DateUtils.formatDate(bPay.getPayDate(), locale);

                                            String colSpan = "1";                                                                       
                                            if (numPayments > 1) {
                                               colSpan="8";
                     %>
                                </tr>
                                <tr class="<%=rowColor%>">
                     <%
                     
                                            }

                      %>
                                            <td colspan="<%=colSpan%>" style="text-align:right"><%=payAmt.toPlainString()%></td>
                                            <td style="text-align:right"><%=refundAmt.toPlainString()%></td>                       
                                            <td style="text-align:center"><%=payDate%></td>  
                                            <td style="text-align:center"></td>
                                </tr>
                                            
                     <%                     
                                            total3rdPaid = total3rdPaid.add(payAmt);
                                            total3rdRefunded = total3rdRefunded.add(refundAmt);
                                          }
                                      }
                                            String outstandingAmt = "";
                                            String fontWeight = "";
                                               if (!bCh1.getPayProgram().equals("HCP")
                                                && !bCh1.getPayProgram().equals("WCB")
                                                && !bCh1.getPayProgram().equals("RMB")
                                                && !bCh1.getStatus().equals(BillingONCHeader1.DELETED)) {
                                                    
                                                    BigDecimal outstandingBalance = totalBilled.subtract(totalPaid).add(totalRefunded);  
                                                    outstandingAmt = outstandingBalance.toPlainString();

                                                    if (outstandingBalance.compareTo(zeroAmt) != 0) {
                                                        fontWeight = "font-weight:bold;";
                                                    }
                                                                                            
                      %>              
                   
                      
                                <tr  class="<%=rowColor%>">
                                            <td colspan="11"style="text-align:right;<%=fontWeight%>"><%=outstandingAmt%></td>               
                                </tr>
                   <%                   } %>
                     
                     <%     
                               }
                           }                                                       
                        }
                    %> 
                    <tr style="background-color:lightblue;">
                        <td colspan="2" style="font-weight:bold;"><bean:message key="oscar.billing.on.paymentReceived.itemCount"/>:</td>
                        <td colspan="3"><%=num3rdItems%></td>
                        <td style="font-weight:bold"><bean:message key="oscar.billing.on.paymentReceived.cumulativeTotal"/>:</td>
                        <td style="text-align:right"><%=total3rdBilled%></td>
                        <td style="text-align:right"><%=total3rdPaid%></td>
                        <td style="text-align:right"><%=total3rdRefunded%></td>
                        <td colspan="2"></td>
                    </tr>
                </table> 
            <% 
                BigDecimal finalAmt = paidTotal.add(total3rdPaid).subtract(total3rdRefunded).add(totalPremiums);
            %>
            <table width="100%" class="myDarkGreen">
                <tr>
                    <td style="width:10%;color:white;font-weight:bold;font-size:14pt;"><bean:message key="oscar.billing.on.paymentReceived.totalPaid"/>:</td>
                    <td style="padding-top:14px;padding-bottom:14px;color:white;font-weight:bold; font-size:14pt;"><%=finalAmt%></td>
                </tr>
            </table>
        </form>
        <script type="text/javascript">                       
            Calendar.setup({inputField:"startDateText",ifFormat:"%Y-%m-%d",showsTime:false,button:"startDate",singleClick:true,step:1});          
            Calendar.setup({inputField:"endDateText",ifFormat:"%Y-%m-%d",showsTime:false,button:"endDate",singleClick:true,step:1}); 
        </script>
    </body>
</html>
