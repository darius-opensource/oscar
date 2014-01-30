package org.oscarehr;

import java.io.*;
import org.apache.commons.io.FileUtils;

import static org.junit.Assert.assertEquals;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.firefox.FirefoxBinary;
import org.openqa.selenium.firefox.FirefoxDriver;

import java.util.regex.Pattern;
import java.util.concurrent.TimeUnit;
import org.junit.*;
import static org.junit.Assert.*;
import static org.hamcrest.CoreMatchers.*;
import org.openqa.selenium.*;
import org.openqa.selenium.firefox.FirefoxDriver;
import org.openqa.selenium.phantomjs.PhantomJSDriver;
import org.openqa.selenium.remote.DesiredCapabilities;
import org.openqa.selenium.support.ui.Select;


public class OscarIntegrationTest {

	private WebDriver webDriver;
	
	private String testServerPort;
	
	private String display;

protected static DesiredCapabilities dCaps;
	
	@Before
	public void openWebDriver() {
		testServerPort = System.getProperty("test.server.port","8080");
        
		String display = System.getProperty("test.xvfb.display",null);
		FirefoxBinary firefox = new FirefoxBinary();
		if( display != null ) {
			firefox.setEnvironmentProperty("DISPLAY", display);
		}
		webDriver = new FirefoxDriver(firefox,null);

        
        
    dCaps = new DesiredCapabilities();
    dCaps.setJavascriptEnabled(true);
    dCaps.setCapability("takesScreenshot", true);
        
//    webDriver = new PhantomJSDriver(dCaps);
        
    DesiredCapabilities capabilities = DesiredCapabilities.phantomjs();	          
	  //webDriver = new PhantomJSDriver(capabilities);
	  webDriver.manage().timeouts().implicitlyWait(30, TimeUnit.SECONDS);
        
	}
	
	@After
	public void closeWebDriver() {
		//webDriver.close();
        webDriver.quit();
	}
	

	@Test
	public void testLogin() throws IOException{
		webDriver.get("http://localhost:"+testServerPort+"/oscar/");
File scrFile = ((TakesScreenshot)webDriver).getScreenshotAs(OutputType.FILE);
FileUtils.copyFile(scrFile, new File("screenshot.png"));		
		
		//assertEquals(1,1);
	}
		
	
}
