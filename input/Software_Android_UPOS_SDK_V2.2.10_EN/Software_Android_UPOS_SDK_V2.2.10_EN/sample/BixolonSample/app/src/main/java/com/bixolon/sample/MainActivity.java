package com.bixolon.sample;

import android.Manifest;
import android.annotation.TargetApi;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.StrictMode;
import android.provider.Settings;
import android.support.annotation.RequiresApi;
import android.support.design.widget.TabLayout;
import android.support.v4.app.ActivityCompat;
import android.support.v4.app.Fragment;
import android.support.v4.content.ContextCompat;
import android.support.v4.view.ViewPager;
import android.support.v7.app.AlertDialog;
import android.support.v7.app.AppCompatActivity;
import android.support.v7.widget.Toolbar;
import android.view.KeyEvent;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.widget.Toast;

import com.bixolon.commonlib.BXLCommonConst;
import com.bixolon.commonlib.log.LogService;
import com.bixolon.sample.PrinterControl.BixolonPrinter;

import java.io.File;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

public class MainActivity extends AppCompatActivity implements View.OnKeyListener {
    private static BixolonPrinter bxlPrinter = null;

    private static Fragment currentFragment;
    private static int currentPosition = 0;

    private Toolbar toolbar;
    private TabLayout mTabLayout = null;
    private ViewPager mViewPager = null;
    private static TabPagerAdapter mPagerAdapter = null;
    private static boolean isRequestPermission = false;

    public static final int showSendData = 100;
    public static final int showSetSerialData = 101;
    public static final int showCustomDevice = 102;


    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        toolbar = findViewById(R.id.toolbar);
        setSupportActionBar(toolbar);

        mTabLayout = findViewById(R.id.main_tab);
        mViewPager = findViewById(R.id.main_viewpager);
        mTabLayout.setupWithViewPager(mViewPager);

        mPagerAdapter = new TabPagerAdapter(this.getSupportFragmentManager(), this);
        mViewPager.setAdapter(mPagerAdapter);
        mViewPager.addOnPageChangeListener(new TabLayout.TabLayoutOnPageChangeListener(mTabLayout));

        mTabLayout.addOnTabSelectedListener(new TabLayout.OnTabSelectedListener() {
            @Override
            public void onTabSelected(TabLayout.Tab tab) {
                mViewPager.setCurrentItem(tab.getPosition());
                currentPosition = tab.getPosition();
            }

            @Override
            public void onTabUnselected(TabLayout.Tab tab) {

            }

            @Override
            public void onTabReselected(TabLayout.Tab tab) {

            }
        });

        final int ANDROID_NOUGAT = 24;
        if (Build.VERSION.SDK_INT >= ANDROID_NOUGAT) {
            StrictMode.ThreadPolicy policy = new StrictMode.ThreadPolicy.Builder().permitAll().build();
            StrictMode.setThreadPolicy(policy);
        }


        bxlPrinter = new BixolonPrinter(getApplicationContext());
        Thread.setDefaultUncaughtExceptionHandler(new AppUncaughtExceptionHandler());

        startConnectionActivity();


        String strPathLOG = "";
        File[] mediaDirs = MainActivity.this.getExternalMediaDirs();
        if (mediaDirs != null && mediaDirs.length > 0) {
            strPathLOG = mediaDirs[0].getPath() + "/Log/";

        } else {
            strPathLOG = MainActivity.this.getFilesDir().getParent() + "/BixolonSample/Log/";
        }
        LogService.InitDebugLog(true,
                true,
                BXLCommonConst._LOG_LEVEL_HIGH,
                128,
                128,
                (1024 * 1024) * 10 /* 10MB */,
                0,
                strPathLOG,
                "bixolonSample.log");

    }


    @Override
    protected void onDestroy() {
        super.onDestroy();
        getPrinterInstance().printerClose();
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        //return super.onCreateOptionsMenu(menu);
        MenuInflater menuInflater = getMenuInflater();
        menuInflater.inflate(R.menu.menu, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        //return super.onOptionsItemSelected(item);
        switch (item.getItemId()) {
            case R.id.action_open:
            case R.id.action_close:
                bxlPrinter.printerClose();
                startConnectionActivity();
                break;
        }

        return true;
    }

    public void startConnectionActivity() {
        Intent intent = new Intent(getApplicationContext(), PrinterConnectActivity.class);
        startActivityForResult(intent, 0);
    }

    public static BixolonPrinter getPrinterInstance() {
        return bxlPrinter;
    }

    public static Fragment getVisibleFragment() {
        currentFragment = mPagerAdapter.getRegisteredFragment(currentPosition);
        return currentFragment;
    }

    @Override
    public boolean onKey(View v, int keyCode, KeyEvent event) {
        switch (keyCode) {
            case KeyEvent.KEYCODE_BACK:
                finish();
                break;

        }
        return true;
    }

    public class AppUncaughtExceptionHandler implements Thread.UncaughtExceptionHandler {
        @Override
        public void uncaughtException(Thread thread, final Throwable ex) {
            ex.printStackTrace();

            android.os.Process.killProcess(android.os.Process.myPid());
            System.exit(10);
        }
    }

}
