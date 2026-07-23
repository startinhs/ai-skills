package com.bixolon.sample;

import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.support.v4.app.Fragment;
import android.text.Layout;
import android.text.method.ScrollingMovementMethod;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import android.widget.Toast;

public class CashDrawerFragment extends Fragment implements View.OnClickListener {

    private TextView deviceMessagesTextView;

    public static CashDrawerFragment newInstance() {
        CashDrawerFragment fragment = new CashDrawerFragment();
        Bundle args = new Bundle();
        fragment.setArguments(args);
        return fragment;
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_cash_drawer, container, false);

        view.findViewById(R.id.buttonCashDrawerOpen).setOnClickListener(this);
        view.findViewById(R.id.buttonDrawerOpen).setOnClickListener(this);
        view.findViewById(R.id.buttonCheckHealth).setOnClickListener(this);
        view.findViewById(R.id.buttonInfo).setOnClickListener(this);
        view.findViewById(R.id.buttonCashDrawerClose).setOnClickListener(this);

        deviceMessagesTextView = view.findViewById(R.id.textViewDeviceMessages);
        deviceMessagesTextView.setMovementMethod(new ScrollingMovementMethod());
        deviceMessagesTextView.setVerticalScrollBarEnabled(true);

        return view;
    }

    @Override
    public void onClick(View view) {
        switch (view.getId()) {
            case R.id.buttonCashDrawerOpen:
                MainActivity.getPrinterInstance().cashDrawerOpen();
                break;
            case R.id.buttonDrawerOpen:
                MainActivity.getPrinterInstance().drawerOpen();
                break;
            case R.id.buttonCheckHealth:
                String checkHealth = MainActivity.getPrinterInstance().cashDrawerCheckHealth();
                if (checkHealth != null) {
                    Toast.makeText(getContext(), checkHealth, Toast.LENGTH_LONG).show();
                }
                break;
            case R.id.buttonInfo:
                String info = MainActivity.getPrinterInstance().getCashDrawerInfo();
                if (info != null) {
                    Toast.makeText(getContext(), info, Toast.LENGTH_LONG).show();
                }
                break;
            case R.id.buttonCashDrawerClose:
                MainActivity.getPrinterInstance().cashDrawerClose();
                break;
        }
    }

    public void setDeviceLog(String data) {
        mHandler.obtainMessage(0, 0, 0, data).sendToTarget();
    }

    public final Handler mHandler = new Handler(new Handler.Callback() {
        @SuppressWarnings("unchecked")
        @Override
        public boolean handleMessage(Message msg) {
            switch (msg.what) {
                case 0:
                    deviceMessagesTextView.append((String) msg.obj + "\n");

                    Layout layout = deviceMessagesTextView.getLayout();
                    if (layout != null) {
                        int y = layout.getLineTop(
                                deviceMessagesTextView.getLineCount()) - deviceMessagesTextView.getHeight();
                        if (y > 0) {
                            deviceMessagesTextView.scrollTo(0, y);
                            deviceMessagesTextView.invalidate();
                        }
                    }
                    break;
            }
            return false;
        }
    });
}
