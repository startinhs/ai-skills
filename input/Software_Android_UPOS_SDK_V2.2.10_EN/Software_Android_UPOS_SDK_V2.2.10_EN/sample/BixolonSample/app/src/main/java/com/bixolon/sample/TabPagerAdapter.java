package com.bixolon.sample;

import android.content.Context;
import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentManager;
import android.support.v4.app.FragmentStatePagerAdapter;
import android.util.SparseArray;
import android.view.ViewGroup;

public class TabPagerAdapter extends FragmentStatePagerAdapter {
    private Context mContext;
    SparseArray<Fragment> registeredFragments = new SparseArray<>();

    private TextFragment mTextFragment = null;
    private ImageFragment mImageFragment = null;
    private BarcodeFragment mBarcodeFragment = null;
    private PageModeFragment mPageModeFragment = null;
    private DirectIOFragment mDirectIOFragment = null;
    private MsrFragment mMsrFragment = null;
    private ScrFragment mScrFragment = null;
    private CashDrawerFragment mCashDrawerFragment = null;
    private EtcFragment mEtcFragment = null;
    private UsbPeripheralFragment mUsbPeripheralFragment = null;

    private int[] mTabTitle = {R.string.Text, R.string.Image, R.string.Barcode, R.string.PageMode, R.string.DirectIO, R.string.MSR, R.string.SCR, R.string.CashDrawer, R.string.ETC, R.string.USBPeripheral};

    public TabPagerAdapter(FragmentManager fm, Context context) {
        super(fm);
        this.mContext = context;
    }

    @Override
    public Object instantiateItem(ViewGroup container, int position) {
        Fragment fragment = (Fragment) super.instantiateItem(container, position);
        registeredFragments.put(position, fragment);
        return fragment;
    }

    @Override
    public void destroyItem(ViewGroup container, int position, Object object) {
        registeredFragments.remove(position);
        super.destroyItem(container, position, object);
    }

    public Fragment getRegisteredFragment(int position) {
        return registeredFragments.get(position);
    }

    @Override
    public Fragment getItem(int position) {
        switch (position) {
            case 0:
                if (mTextFragment == null) {
                    mTextFragment = mTextFragment.newInstance();
                }
                return mTextFragment;
            case 1:
                if (mImageFragment == null) {
                    mImageFragment = mImageFragment.newInstance();
                }
                return mImageFragment;
            case 2:
                if (mBarcodeFragment == null) {
                    mBarcodeFragment = mBarcodeFragment.newInstance();
                }
                return mBarcodeFragment;
            case 3:
                if (mPageModeFragment == null) {
                    mPageModeFragment = mPageModeFragment.newInstance();
                }
                return mPageModeFragment;
            case 4:
                if (mDirectIOFragment == null) {
                    mDirectIOFragment = mDirectIOFragment.newInstance();
                }
                return mDirectIOFragment;
            case 5:
                if (mMsrFragment == null) {
                    mMsrFragment = mMsrFragment.newInstance();
                }
                return mMsrFragment;
            case 6:
                if (mScrFragment == null) {
                    mScrFragment = mScrFragment.newInstance();
                }
                return mScrFragment;
            case 7:
                if (mCashDrawerFragment == null) {
                    mCashDrawerFragment = mCashDrawerFragment.newInstance();
                }
                return mCashDrawerFragment;
            case 8:
                if (mEtcFragment == null) {
                    mEtcFragment = mEtcFragment.newInstance();
                }
                return mEtcFragment;
            case 9:
                if (mUsbPeripheralFragment == null) {
                    mUsbPeripheralFragment = mUsbPeripheralFragment.newInstance();
                }
                return mUsbPeripheralFragment;


            default:
                return null;
        }
    }

    @Override
    public CharSequence getPageTitle(int position) {
        return mContext.getString(mTabTitle[position]);
    }

    @Override
    public int getCount() {
        return mTabTitle.length;
    }
}
